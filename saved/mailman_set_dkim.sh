#!/bin/bash

#set_dns_record 'mailman.opensource-expert.com' TXT 'v=spf1 mx -all'

set_dns_record  '2020._domainkey.mailman.opensource-expert.com' DKIM 'v=DKIM1;h=sha256;k=rsa;n=AGU3L;s=*;p=MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAuT2e6ZeX+0whsXDOQOqwbpDyH/tN1csW36niZrvlJIUcjKk0hmKkGIe8HPXI33yUIhvgCMSAG1zmEPLR5cQ6fLEeb4+BE6hclVe6MpJDLCyUT7ZtKXwY0i3srtTWe1iYxFL6r+ekJsy0GL9TCc7hAmepW/0oXGpuZoqCeE8mzf5t7u6hsxepEKVa76mB1EW91QkGWn4IxSafOpyWyBtCp5npGIwFcmiD8wkUAslpSKx5T7E5+NRC8WZUqfgJRw8T8gYvPVn3zY8/qSgArKtryU/JqAf/mfC3RAgoZlM+7Xu0p2A4M+xRa9qVsDguZkZr14forv5uTCV3RZunvOQqGwIDAQAB;t=s;'
