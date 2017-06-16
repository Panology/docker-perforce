#!/bin/bash
set -e
export NAME="${NAME:-p4depot}"
export DATAVOLUME="${DATAVOLUME:-/data}"
export P4ROOT="${DATAVOLUME}/${NAME}"
export P4CONFIG="${P4CONFIG:-.p4config}"

if [ ! -d $DATAVOLUME/etc ]; then
    echo >&2 "First time installation, copying configuration from /etc/perforce to $DATAVOLUME/etc and relinking"
    mkdir -p $DATAVOLUME/etc
    cp -r /etc/perforce/* $DATAVOLUME/etc/
    FRESHINSTALL=1
fi

mv /etc/perforce /etc/perforce.orig
ln -s $DATAVOLUME/etc /etc/perforce

if [ -z "$P4PASSWD" ]; then
    P4PASSWD="pass12349ers!"
fi

# This is hardcoded in configure-helix-p4d.sh :(
P4SSLDIR="$P4ROOT/ssl"

for DIR in $P4ROOT $P4SSLDIR; do
    mkdir -m 0700 -p $DIR
    chown perforce:perforce $DIR
done

if ! p4dctl list 2>/dev/null | grep -q $NAME; then
    /opt/perforce/sbin/configure-helix-p4d.sh $NAME -n -p $P4PORT -r $P4ROOT -u $P4USER -P "${P4PASSWD}"
fi

if echo "$P4PORT" | grep -q '^ssl:'; then
    p4 trust -y
fi

cat > ~perforce/${P4CONFIG} <<EOF
P4USER=$P4USER
P4PORT=$P4PORT
P4PASSWD=$P4PASSWD
EOF
chmod 0600 ~perforce/${P4CONFIG}
chown perforce:perforce ~perforce/${P4CONFIG}

p4 login <<EOF
$P4PASSWD
EOF

if [ "$FRESHINSTALL" = "1" ]; then
    ## Load up the default tables
    echo >&2 "First time installation, setting up defaults for p4 user, group and protect tables"
    p4 user -i < /root/p4-users.txt
    p4 group -i < /root/p4-groups.txt
    p4 protect -i < /root/p4-protect.txt
fi

echo "   P4USER=$P4USER (the admin user)"

if [ "$P4PASSWD" == "pass12349ers!" ]; then
    echo -e "\n***** WARNING: USING DEFAULT PASSWORD ******\n"
    echo "Please change as soon as possible:"
    echo "   P4PASSWD=$P4PASSWD"
    echo -e "\n***** WARNING: USING DEFAULT PASSWORD ******\n"
fi
