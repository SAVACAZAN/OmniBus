#!/bin/bash
# backup_create.sh
tar -czf omnibus_backup_$(date +%Y%m%d).tar.gz /etc/omnibus /var/lib/omnibus