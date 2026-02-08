pipeline {
    agent any

    environment {
        // 1. Terraform 配置
        TERRAFORM_DIR = "./terraform-eks"
        TF_VAR_CLUSTER_NAME = "jenkins-bluegreen-eks"
        TF_VAR_NAMESPACE = "jenkins-bluegreen-deploy"

        // 2. 代码仓库配置
        GIT_REPO_URL = "https://gitee.com/your-repo/your-app.git"
        GIT_BRANCH = "main"

        // 3. SonarQube 配置
        SONAR_PROJECT_KEY = "my-app-bluegreen"  // Sonar 中唯一项目标识
        SONAR_PROJECT_NAME = "My App BlueGreen Deploy"
        SONAR_HOST_URL = "http://your-sonar-server:9000"  // 替换为你的 Sonar 地址
        SONAR_LOGIN_TOKEN = credentials("sonar-qube-token")  // Jenkins 中配置的 Sonar 凭证

        // 4. 镜像构建/推送配置
        DOCKER_REGISTRY = "your-docker-registry.cn"
        DOCKER_IMAGE_NAME = "my-app"
        DOCKER_IMAGE_TAG = "v1.0.0"
        FULL_DOCKER_IMAGE = "${DOCKER_REGISTRY}/${DOCKER_IMAGE_NAME}:${DOCKER_IMAGE_TAG}"
        DEFAULT_BLUE_IMAGE_TAG = "latest"

        // 5. 蓝绿部署核心配置
        K8S_NAMESPACE = "${TF_VAR_NAMESPACE}"
        HELM_CHART_DIR = "./my-app-chart"
        APP_NAME = "my-business-app"
        SERVICE_NAME = "${APP_NAME}-service"
        BLUE_ENV = "blue"
        GREEN_ENV = "green"
        BLUE_HELM_RELEASE = "${APP_NAME}-${BLUE_ENV}"
        GREEN_HELM_RELEASE = "${APP_NAME}-${GREEN_ENV}"
        HELM_DEPLOY_TIMEOUT = "5m"
        HEALTH_CHECK_TIMEOUT = "3m"
        HPA_MIN_REPLICAS = 2
        HPA_MAX_REPLICAS = 10
        HPA_CPU_TARGET_UTILIZATION = 70

        LABEL_KEY = "env"
        SERVICE_NAME = "my-business-app-service"
    }
    parameters {
        booleanParam(
            name: "CLEAN_OLD_BLUE_ENV",
            defaultValue: true,
            description: "发布成功后是否清理蓝环境"
        )
        booleanParam(
            name: "TERRAFORM_DESTROY_AFTER_DEPLOY",
            defaultValue: false,
            description: "部署完成后是否销毁 Terraform 基础设施（仅测试环境）"
        )
        
        string(name: 'LABEL_KEY', defaultValue: 'env', desc: '蓝绿标签键')
    }

    // 完整流程：Terraform → 拉代码 → Sonar 检测 → 构建镜像 → 蓝绿部署 → 可选销毁
    stages {
        stage("Provision Infra with Terraform") {
            steps {
                echo "===== 检查/创建基础设施，避免重复执行 Terraform ====="
                sh """
                    cd ${TERRAFORM_DIR}
                    terraform init
                    terraform validate
                    if terraform state list | grep -q "eks_cluster" && kubectl get ns ${K8S_NAMESPACE} >/dev/null 2>&1; then
                        echo "===== 基础设施已存在，跳过 Terraform apply ====="
                    else
                        echo "===== 执行 Terraform 创建集群+namespace ====="
                        terraform apply -auto-approve -var "cluster_name=${TF_VAR_CLUSTER_NAME}" -var "namespace=${TF_VAR_NAMESPACE}"
                    fi
                    # 读取 Terraform output 并写入 kubeconfig 配置文件
                    mkdir -p ~/.kube
                    terraform output -raw kubeconfig > ~/.kube/config
                    # 验证 kubeconfig 有效性
                    kubectl get nodes
                """
            }
        }

        stage("Pull Source Code from Git") {
            steps {
                echo "===== 拉取 ${GIT_BRANCH} 分支代码 ====="
                git url: "${GIT_REPO_URL}", branch: "${GIT_BRANCH}", credentialsId: "your-git-credentials"
            }
        }

        // 核心新增：SonarQube 代码质量检测阶段（质量门禁）
        stage("SonarQube Code Quality Analysis") {
            options {
                timeout(time: 10, unit: "MINUTES")  // Sonar 检测超时控制
            }
            steps {
                echo "===== 开始 SonarQube 代码质量检测 ====="
                // 使用 sonar-scanner 执行代码扫描（需项目根目录有 sonar-project.properties，或直接在命令行指定配置）
                sh """
                    sonar-scanner \
                      -Dsonar.projectKey=${SONAR_PROJECT_KEY} \
                      -Dsonar.projectName=${SONAR_PROJECT_NAME} \
                      -Dsonar.host.url=${SONAR_HOST_URL} \
                      -Dsonar.login=${SONAR_LOGIN_TOKEN} \
                      -Dsonar.sources=. \
                      -Dsonar.language=java \  // 替换为你的项目语言（js/python 等）
                      -Dsonar.java.binaries=target/classes \  // 编译产物目录（根据项目调整）
                      -Dsonar.qualitygate.wait=true  // 等待质量门禁结果，不合格则终止
                """
                echo "===== SonarQube 检测通过，代码质量符合要求 ====="
            }
        }

        stage("Build & Push Docker Image") {
            steps {
                echo "===== 构建并推送镜像：${FULL_DOCKER_IMAGE} ====="
                withCredentials([usernamePassword(credentialsId: "your-docker-registry-credentials", usernameVariable: "DOCKER_USER", passwordVariable: "DOCKER_PWD")]) {
                    sh """
                        docker login ${DOCKER_REGISTRY} -u ${DOCKER_USER} -p ${DOCKER_PWD}
                        docker build -t ${FULL_DOCKER_IMAGE} .
                        docker push ${FULL_DOCKER_IMAGE}
                        docker logout ${DOCKER_REGISTRY}
                    """
                }
            }
        }

        # 把之前成功部署pod的green标签改为blue，就是重置把流量回原来蓝色的稳定状态，以免第二次部署失败
        stage("Change green to blue") {
            steps {
                # 1. 精准匹配绿色标签Pod，覆盖为蓝色标签（指定命名空间，无Pod匹配也不会报错）
                sh "kubectl label pod -n $K8S_NAMESPACE} -l app=${APP_NAME},${LABEL_KEY}=${GREEN_ENV} ${LABEL_KEY}=${} --overwrite"
             
                # 2. 刷新Service Endpoint（重建端点，让Service重新识别蓝标签Pod，无重启、无流量中断）
                sh "kubectl patch service ${SERVICE_NAME} -n ${K8S_NAMESPACE} -p '{"spec":{"selector":{"'${LABEL_KEY}'":"'${BLUE_ENV}'"}}}'"

                sh """
                # 3.执行命令并捕获返回码,非0返回码则终止并抛出错误
                 kubectl get service ${SERVICE_NAME} -n ${K8S_NAMESPACE} -o jsonpath='{.spec.selector}'
                 exit_code=\$?
    
                if [ \$exit_code -ne 0 ]; then
                  echo "获取Service配置失败"
                  exit 1
                fi
               """
            }
        }
        
        stage("Pre-Check (Env + HPA Dependen)") {
            steps {
                echo "===== 前置检查 ====="
                sh "kubectl version --client"
                sh "helm version --short"
                sh "kubectl get ns ${K8S_NAMESPACE} || (echo 'Namespace 不存在' && exit 1)"
                sh "test -d ${HELM_CHART_DIR} || (echo 'Chart 目录不存在' && exit 1)"
                sh "kubectl get deployment metrics-server -n kube-system > /dev/null 2>&1 || (echo 'metrics-server 不存在' && exit 1)"
            }
        }

        stage("Deploy Green Env (Service+Deployment+HPA)") {
            options {
                timeout(time: HELM_DEPLOY_TIMEOUT, unit: "MINUTES")
            }
            steps {
                echo "===== 部署绿环境 ====="
                sh """
                    helm upgrade --install ${GREEN_HELM_RELEASE} ${HELM_CHART_DIR} \
                      -n ${K8S_NAMESPACE} \
                      --set image.repository=${DOCKER_REGISTRY}/${DOCKER_IMAGE_NAME} \
                      --set image.tag=${DOCKER_IMAGE_TAG} \
                      --set app.env=${GREEN_ENV} \
                      --set hpa.minReplicas=${HPA_MIN_REPLICAS} \
                      --set hpa.maxReplicas=${HPA_MAX_REPLICAS} \
                      --set hpa.cpuTargetUtilization=${HPA_CPU_TARGET_UTILIZATION} \
                      --timeout ${HELM_DEPLOY_TIMEOUT} \
                      --create-namespace=false

                sh """
                   # 返回码非0，有错误提示
                   def resStatus = sh(
                       script: "kubectl get deployment ${GREEN_HELM_RELEASE}-${APP_NAME} -n ${K8S_NAMESPACE} && kubectl get hpa ${GREEN_HELM_RELEASE}-${APP_NAME} -n ${K8S_NAMESPACE}",
                      returnStatus: true
                   )
                  if (resStatus != 0) {
                      error "depoyment 或 HPA 不存在"
                  }
                """
            }
        }

        stage("Switch Traffic to Green Env") {
            steps {
                echo "===== 切换流量到绿环境 ====="
                sh """
                    helm template ${GREEN_HELM_RELEASE} ${HELM_CHART_DIR} \
                      -n ${K8S_NAMESPACE} \
                      --set app.env=${GREEN_ENV} \
                      --set app.name=${APP_NAME} \
                      --show-only templates/service.yaml \
                      | kubectl apply -n ${K8S_NAMESPACE} -f -
                """
                sh """
                
                def selectorCheck = sh(
                     script: "kubectl get svc ${SERVICE_NAME} -n ${K8S_NAMESPACE} -o jsonpath='{.spec.selector}' | grep -E '${GREEN_HELM_RELEASE}|${GREEN_ENV}'",
                      returnStatus: true
                  )
                if (selectorCheck != 0) error "Service selector未指向绿环境，配置更新失败"
                """     
            }
        }

        stage("Clean Old Blue Env (Service+Deployment+HPA)") {
            when {
                expression { params.CLEAN_OLD_BLUE_ENV == true }
            }
            steps {
                echo "===== 清理蓝环境 ====="
                sh """
                    helm uninstall ${BLUE_HELM_RELEASE} -n ${K8S_NAMESPACE} --ignore-not-found
                    kubectl delete pods -n ${K8S_NAMESPACE} -l app=${APP_NAME},env=${BLUE_ENV} --ignore-not-found
                """
                
                sh """
                 # 检查helm release是否残留
                 helm status ${BLUE_HELM_RELEASE} -n ${K8S_NAMESPACE} >/dev/null 2>&1
                 HELM_EXIT=\$?
    
                 # 检查blue标签pod是否残留
                 kubectl get pods -n ${K8S_NAMESPACE} -l app=${APP_NAME},env=${BLUE_ENV} >/dev/null 2>&1
                 POD_EXIT=\$?
    
                 # 有残留则返回非0码，无残留返回0
                 if [ \$HELM_EXIT -eq 0 ] || [ \$POD_EXIT -eq 0 ]; then
                   echo "资源未清理干净：helm release或blue pod仍存在"
                   exit 1
                else
                   echo "所有目标资源已清理完成"
                   exit 0
                fi
            """
            }
        }
        
        stage("Destroy Infra with Terraform (Optional)") {
            when {
                expression { params.TERRAFORM_DESTROY_AFTER_DEPLOY == true }
            }
            steps {
                echo "===== 销毁基础设施 ====="
                sh """
                    cd ${TERRAFORM_DIR}
                    terraform destroy -auto-approve -var "cluster_name=${TF_VAR_CLUSTER_NAME}" -var "namespace=${TF_VAR_NAMESPACE}"
                """
            }
        }
    }

    post {
        success {
            echo "===== 全流程执行成功，新版本已上线 ====="
        }
        failure {
            echo "===== 流程失败，自动回滚 ====="
            sh """
                helm uninstall ${GREEN_HELM_RELEASE} -n ${K8S_NAMESPACE} --ignore-not-found
                if ! helm list -n ${K8S_NAMESPACE} | grep -q ${BLUE_HELM_RELEASE}; then
                    helm upgrade --install ${BLUE_HELM_RELEASE} ${HELM_CHART_DIR} \
                      -n ${K8S_NAMESPACE} \
                      --set image.repository=${DOCKER_REGISTRY}/${DOCKER_IMAGE_NAME} \
                      --set image.tag=${DEFAULT_BLUE_IMAGE_TAG} \
                      --set app.env=${BLUE_ENV} \
                      --set hpa.minReplicas=${HPA_MIN_REPLICAS} \
                      --set hpa.maxReplicas=${HPA_MAX_REPLICAS} \
                      --set hpa.cpuTargetUtilization=${HPA_CPU_TARGET_UTILIZATION} \
                      --timeout ${HELM_DEPLOY_TIMEOUT} \
                      --create-namespace=false
                fi
                
                sh """                   
                def resStatus = sh(                       
                      script: "kubectl get deployment ${BLUE_HELM_RELEASE}-${APP_NAME} -n ${K8S_NAMESPACE} && kubectl get hpa ${BLUE_HELM_RELEASE}-${APP_NAME} -n ${K8S_NAMESPACE}",                      
                returnStatus: true
                )                  
                if (resStatus != 0) {
                    error "depoyment 或 HPA 不存在"
                }                
                """
                
                helm template ${BLUE_HELM_RELEASE} ${HELM_CHART_DIR} \
                  -n ${K8S_NAMESPACE} \
                  --set app.env=${BLUE_ENV} \
                  --set app.name=${APP_NAME} \
                  --show-only templates/service.yaml \
                  | kubectl apply -n ${K8S_NAMESPACE} -f -
                 """
                sh """               
                def selectorCheck = sh(
                     script: "kubectl get svc ${SERVICE_NAME} -n ${K8S_NAMESPACE} -o jsonpath='{.spec.selector}' | grep -E '${BLUE_HELM_RELEASE}|${BLUE_ENV}'",
                      returnStatus: true
                  )
                if (selectorCheck != 0) error "Service selector未指向蓝环境，配置更新失败"
                """   
        }
    }

}




