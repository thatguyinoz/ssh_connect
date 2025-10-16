#!/bin/bash

# facilitate an ssh session with commonly used hosts

#Changelog:
#Ver: 0.00
#	basic todo list created


VERSION=0.00
myhosts="~/.config/mysshhosts.conf"


Somehosts() {
#some prviously used hosts
#ssh hopcon@192.168.150.201 -p 222
#ssh root@unifi.hctech.com.au
#ssh root@dns.corp.hctech.com.au
#ssh root@unifi.corp.hctech.com.au
#ssh peterhop@datacaptureservices.com.au
#ssh root@192.168.150.66
#ssh root@ha-cust.hctech.com.au
#ssh hopcon@ha-cust.hctech.com.au
#ssh hopcon@192.168.9.167
#ssh hopcon@tdavid-gw.cust.hctech.com.au -p222
#ssh gemini@192.168.150.144
#ssh hopcon@192.168.150.71
#ssh root@dns.corp.hctech.com.au
#ssh root@pythia.penguincare.com.au
#echo "ssh root@pythia.penguincare.com.au" > penguincare_dns_update.txt
#echo "use ssh keys fron kube or dyndns" >> penguincare_dns_update.txt
#ssh hopcon@202.171.177.48 -p 222
#ssh hopcon@mosc-yall.cust.hctech.com.au -p 222
#ssh admin@202.65.82.254 -p 222
#ssh root@202.65.82.254 -p 222
#ssh root@202.65.82.254 -p 222
#ssh hopcon@202.171.177.48 -p 222
#ssh phopkinson@adsl.book-keepingnetwork.com.au -p 222
#ssh root@115.131.134.205 -p 222
#ssh root@203.221.10.236 -p 222
#ssh root@110.175.131.160 -p 222
#ssh root@jhouse.cust.hctech.com.au -p 222
#ssh root@vintage-gw.cust.hctech.com.au -p 222
#ssh hopcon@migaust-gw.cust.hctech.com.au -p 222
}

help_text() {
echo "usage: $0 arg arg arg"
}




