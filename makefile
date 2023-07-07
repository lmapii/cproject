project_name=cproject

builder-build :
	docker build -f builder.Dockerfile -t $(project_name)-builder:latest .
