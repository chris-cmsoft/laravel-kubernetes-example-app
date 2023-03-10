# Laravel In Kubernetes app

This app is the core project used and built 
with the [Laravel In Kubernetes Series](https://chris-vermeulen.com/tag/laravel-in-kubernetes/).

The project is built and productionized, specifically for running in Kubernetes.

## What's different

This application is pretty much stock standard Laravel with Auth built in, 
with the possibility of adding a few endpoints for specific things like Health Checks.

Laravel ships with [Laravel Sail](https://laravel.com/docs/8.x/sail) which has a Docker image, 
and a docker compose setup specialised for local development.

The blog series, and application, are built with some ideas in mind which are different to the default Sail setup,
such as Alpine images, different image builds for different purposes (Nginx, FPM, CLI etc.), and a couple nice changes.

## Getting running

If you'd like to run the project locally, you can simply run `docker-compose up -d`, 
and the app will be exposed on port 8080.

## Docker specifics

There are multiple ways to build the different images, but this repo uses a multi stage build, 
with different stages for each of the different pieces.

The reason for doing it this way is to install all dependencies in one stage, 
and copy in the code base into specific stages, which are specialised for their specific use like FPM, CLI or Nginx.
