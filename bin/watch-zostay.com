#!/bin/bash

kubectl logs -l app=zostay-com --all-containers=true -f
