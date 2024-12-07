# How to run?

## Get Image

You can select pre-built image or build yourself.

### Use pre-build image

See [Docker Hub](https://hub.docker.com/r/dao0312/zarathu_dev)

### Build

or you can build yourself.

At first, clone this repository by

`git clone https://github.com/zarathucorp/devenv-docker`

Move to folder

`cd devenv-docker`

Run

`docker build -t devenv-docker:v241207 .`

Tag is optional.

## Run Image

It uses two ports, 3838 and 8787.

Run

`docker run -itd -p 3838:3838 -p 8787:8787 -v <host volume location>:/home devenv-docker:v241207`

You can access localhost:3838/shiny/<user_name> for Shiny Server and localhost:8787 for RStudio Server

#### Why volume share is important?

Without volume share, container usage will get more and more bigger.

To save storage, use -v option.

## **Please leave message to issue tab for any inquiries**

I'll be happy to help you.

For example, I'm using nginx for https support. If you want to know how, leave it at issue tab!
