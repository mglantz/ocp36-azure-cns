#!/bin/bash
# Magnus Glantz, sudo@redhat.com, 2017
# To be run on scheduble OpenShift nodes to resolve https://bugzilla.redhat.com/show_bug.cgi?id=1489082
# You can put this in a crontab and run once a minute or so as a workaround. 
# Allow around 2 minutes for stuck pod or project with stuck pod in it to get deleted after this script is run.

# DON'T RUN IT IF YOU DON'T UNDERSTAND WHAT IT DOES.
# If there are glusterfs volumes other than the ones coming from CNS, they will be unmounted.

# This script needs to run as root or a user which can run fusermount-glusterfs -u

# Fetch token of cluster admin with 'oc whoami -t' and put value here.
TOKEN=
# FQDN of OCP server
OCPSERVER="https://example-server:8443"
# Change below to yes to unmount volumes detected as stale
DANGERZONE="no"

oc login --token=$TOKEN $OCPSERVER >/dev/null 2>&1
if [ "$?" -eq 0 ]; then
	echo "Logged in to $OCPSERVER"
else
	echo "Failed to login to $OCPSERVER"
fi

echo "Checking for stale CNS volumes."
# List of gluster volume names associated to all provisioned PVs
PVS=$(for item in $(oc get pv|grep glusterfs-storage|awk '{ print $1 }'); do oc describe pv $item|grep "Path:"|cut -d':' -f2; done)
# List of gluster volume names on this node
MOUNTED_VOLS=$(mount|grep glusterfs|awk '{ print $1 }'|cut -d: -f2)

for vol in ${MOUNTED_VOLS[@]}; do
	if [ "$PVS" != "" ]; then
		if echo $PVS|grep $vol >/dev/null; then
			echo "$vol is in the list of provisioned volumes."
		else
			echo "$vol is not found in the list of provisioned volumes"
			if [ "$DANGERZONE" == "yes" ]; then
				echo "Unmounting $vol."
				fusermount-glusterfs -u $item $(mount|grep $vol|awk '{ print $3 }')		
			else
				echo "Stale volume: $(mount|grep $vol|awk '{ print $3 }')"
			fi
		fi
	else
		echo "$vol is not found in the list of provisioned volumes"
		if [ "$DANGERZONE" == "yes" ]; then
			fusermount-glusterfs -u $item $(mount|grep $vol|awk '{ print $3 }')
		else
			echo "Stale volume: $(mount|grep $vol|awk '{ print $3 }')"
		fi
	fi
done

