# Kirby: AI 커버 실시간 스트리밍 서비스

## Introduction
AI 커버를 찾아 들으신 적이 있나요?
또는, 직접 AI 커버를 만들어보려 시도한 적이 있나요?

많은 사람들이 AI 커버에 관심을 갖고 있음에도 불구하고,
직접 제작하거나 원하는 커버를 찾는 과정은 여전히 어렵고 번거롭습니다.

이에 우리는 사용자가 현재 듣고 있는 음악을 선택한 가수의 음성으로 실시간 변환하여 스트리밍 형태로 제공하는 앱 기반 서비스를 제안합니다.

## Demo
[▶ Demo Video](https://github.com/user-attachments/assets/1aecd21c-6e82-4270-bfb4-c086400cd742)

## Architecture
<img width="1648" alt="Image" src="https://github.com/user-attachments/assets/554c5d37-dc99-46c0-a812-6b889dbe53ba" />

## Settings
### 1. client
```
# pwd: .../kirby/client
flutter pub get

# .env 파일 작성
BACKEND_IP=your_backend_ip
BACKEND_PORT=your_backend_port

# ios/Runner/Config.xcconfig 파일 작성
FIREBASE_API_KEY = your_api_key_here
FIREBASE_PROJECT_ID = your_project_id_here
FIREBASE_BUNDLE_ID = your_bundle_id_here
FIREBASE_GCM_SENDER_ID = your_gcm_sender_id_here
FIREBASE_STORAGE_BUCKET = your_storage_bucket_here
FIREBASE_GOOGLE_APP_ID = your_google_app_id_here
# 이후 Xcode에서 프로젝트를 열고 Build Settings로 이동, Configuration File을 검색하여 Config.xcconfig 파일을 설정
```

### 2. server
```
# pwd: .../kirby/server
pip install -r requirements.txt

# .env 파일 작성
SSH_HOST=your_gpu_server
SSH_USER=your_gpu_server_id
SSH_PASSWORD=your_gpu_server_pw
SSH_PORT=your_ssh_port

# input 디렉토리 생성
# output 디렉토리 생성
# serviceAccountKey.json ••• Firebase에서 생성 가능
```

### 3. gpu server
# 사용할 GPU 서버의 디렉토리 


## Members
| 명승준 | 서지은 |
| :-: | :-: |
| <a href="https://github.com/msj99"><img src='https://avatars.githubusercontent.com/u/74344298?v=4' height=130 width=130></img></a> | <a href="https://github.com/maiteun"><img src='https://avatars.githubusercontent.com/u/54938691?v=4' height=130 width=130></img></a>

## Acknowledgements

This project utilizes code from the following third-party repositories. We are grateful to the original authors for their contributions.

-   **rvc-cli / Applio**
    -   **Author/Group:** IAHispano
    -   **Repository:** [https://github.com/IAHispano/Applio](https://github.com/IAHispano/Applio)
    -   **License:** Creative Commons Attribution-NonCommercial 4.0 International
    -   **Note:** The `gpu_server_dir/rvc-cli` directory contains a version of the `rvc-cli` tool, which is now part of the Applio project. The original `LICENSE` and `README.md` files are retained within that directory as required.