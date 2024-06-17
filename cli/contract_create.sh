#!/usr/bin/env bash

aiken build --trace-level verbose ..
aiken blueprint convert .. > contract_code.txt
aiken blueprint address .. > contract_address.txt
