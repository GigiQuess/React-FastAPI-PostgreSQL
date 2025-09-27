# とりあえず
bash ./scripts/post-compose-setup.sh

# backendだけ起動やコンテナのリビルド、クリンナップ
makeコマンド

# dockerイメージ管理
https://www.kagoya.jp/howto/cloud/container/dockerimagedelete/

# dockerビルドキャッシュ
docker system df
docker system prune --volumes

# python仮想環境
source venv/bin/activate