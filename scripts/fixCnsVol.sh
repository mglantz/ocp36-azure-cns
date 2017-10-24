#!/bin/bash

TOKEN=
OCPSERVER=""
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

