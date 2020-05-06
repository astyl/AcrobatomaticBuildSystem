#!/bin/sh

APP=__app__
VERSION=__version__
PKVERSION=__kversion__
KVERSION=`uname -r`
PREFIX="/"

THIS=$0
SKIP=`awk '/^__END_SCRIPT_TAG__$/ { print NR + 1; exit 0; }' "$THIS"` 

help() {
cat << EOF
$1 <cmd> [cmd args]

  Available commands as <cmd> :

    install : install kernel module package $APP $VERSION
      optionnal arg : installation prefix. Default is $PREFIX

    extract : extract embedded tar gz archive as $APP-$VERSION-$PKVERSION.bin.tar.gz
      optionnal arg : alternate target file

    list : list modules
    
    changeGroups : Change the device group in all $APP configuration files
      require arg : new group
      optionnal arg : installation prefix. Default is $PREFIX

    activate : activate a kernel module
      mandatory arg : module name

    help : display help info
EOF
exit 0
}


createDefaultService() {
cat > $1 << EOF
# This file is part of systemd
# This file has been automatically generated by abs

[Unit]
Description=$(basename -- $2) driver
ConditionFileIsExecutable=$2
After=network.target
Before=rc.local.service

[Service]
Type=forking
ExecStart=$2 start
ExecStop=$2 stop
TimeoutSec=0
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF
}

install() {
	if [ "$PKVERSION" != "$KVERSION" ]
	then
		echo "Warning! current kernel version ($KVERSION) doesn't match package target version ($PKVERSION)."
		echo "Continue (y/n)?."
		read rep
		if [ "$rep" != "y" -a "$rep" != "Y" ]
		then
			exit 1
		fi
	fi
	if [ $# -eq 1 ]
	then
		PREFIX="$1"
	fi
	echo "Welcome to $APP $VERSION installation."
	if [ -r "$PREFIX" ]
	then
		echo "Warning: target directory already exists. Continue (y/n) ?"
		read rep
		if [ "$rep" != "y" -a "$rep" != "Y" ]
		then
			exit 1
		fi
	else
		mkdir -p "$PREFIX" 
	fi

	if [ ! -w "$PREFIX" ]
	then
		echo "Can't create installation path. Check path or gain required write access."
		exit 2
	fi

	mkdir -p "$PREFIX/lib/modules/$PKVERSION/$APP"
	tail -n +$SKIP "$THIS" | tar -xvz --overwrite -C "$PREFIX/lib/modules/$PKVERSION/$APP" --strip-components=2 lib/modules
    mkdir -p "$PREFIX/etc/$APP"
    tail -n +$SKIP "$THIS" | tar -xvz -C "$PREFIX/etc/$APP" --strip-components=2 --keep-old-files --wildcards etc/$APP/*.conf
    mkdir -p "$PREFIX/etc/$APP/inits"
    mkdir -p "$PREFIX/etc/$APP/services"
    tail -n +$SKIP "$THIS" | tar -xvz --overwrite -C "$PREFIX/etc/$APP" --strip-components=2 etc/$APP/services etc/$APP/inits 2> /dev/null
    mkdir -p "$PREFIX/etc/init.d"
    tail -n +$SKIP "$THIS" | tar -xvz --overwrite -C "$PREFIX/etc/init.d" --strip-components=2 etc/init.d 
    
    # check that the inits directory exists and that inits contains file.
    if [ -d "$PREFIX/etc/$APP/inits" -a ! -z "$(ls -A $PREFIX/etc/$APP/inits)" ]; then
        chmod 750 $PREFIX/etc/$APP/inits/*
        
        if [ "$(which systemd)" != "" ]; then
            echo "Installation des drivers pour systemd"
            mkdir -p "$PREFIX/lib/systemd/system"
            for initFile in `ls $PREFIX/etc/$APP/inits/*`; do
                serviceFile="$PREFIX/etc/$APP/services/$(basename -- $initFile).service"
                if [ ! -f $serviceFile ]; then 
                    echo "Create default service file $serviceFile"
                    createDefaultService $serviceFile $initFile
                fi
                echo "Linking $serviceFile into $PREFIX/lib/systemd/system"
                # the .service must not be executable
                chmod 640 $serviceFile
                chmod 750 $initFile
                ln -srf "$serviceFile" "$PREFIX/lib/systemd/system/"
            done
        else
            echo "Installation des drivers avec init.d"
            for execFile in `ls "$PREFIX/etc/$APP/inits/*"`; do
                echo "Linking $execFile into init.d"
                chmod 750 $execFile
                ln -srf "$execFile" "$PREFIX/etc/init.d/"
            done
        fi
    fi
	depmod -a

	echo "File Installation done. Restart or reload related services and modules to complete installation."
}

extract() {
	target=$APP-$VERSION-$PKVERSION.bin.tar.gz
	if [ $# -eq 1 ]
	then
		target="$1"
	fi
	if [ -f "$target" ]
	then
		echo "Warning: target file already exists. Continue (y/n)?"
		read rep
		if [ "$rep" != "y" -a "$rep" != "Y" ]
		then
			exit 1
		fi
	fi
	tail -n +$SKIP "$THIS" > "$target"
	echo "Extraction completed."
}

list() {
	tail -n +$SKIP "$THIS" | tar -tz etc/init.d | sed 's/etc\/init\.d\/\(.*\)/\1/g'
    tail -n +$SKIP "$THIS" | tar -tz etc/$APP/inits | sed "s/etc\/$APP\/inits\/\(.*\)/\1/g"
}

changeGroups() {
    if [ $# -lt 1 ]
    then
        help $0
    fi
    NEW_GROUP="$1"
    if [ $# -eq 2 ]
    then
        PREFIX="$2"
    fi
    
    if [ -d "$PREFIX/etc/$APP" ]; then
        for initFile in `ls $PREFIX/etc/$APP/*.conf`; do
            echo "Changing group in $initFile"
            sed -ie "s/DEVGROUP=.*/DEVGROUP=$NEW_GROUP/g" $initFile
        done
    fi
}

activate() {
	if [ $# -eq 1 ]; then
		moduleName=$1
		echo "Activation of the module $moduleName"
		if [ -f /etc/init.d/$moduleName ]; then 
			chmod 750 /etc/init.d/$moduleName
			which chkconfig && chkconfig --add $moduleName
			which update-rc.d && update-rc.d $moduleName defaults
			echo "Starting device..."
			/etc/init.d/$moduleName start
			echo "Activation finished"
	    elif [ -f /lib/systemd/system/$moduleName.service ]; then
	        # the file must not be executable
	        chmod 640 /lib/systemd/system/$moduleName.service
	        systemctl daemon-reload
            echo "Enabling $moduleName"
	        systemctl enable $moduleName
	        echo "Restarting $moduleName"
            systemctl restart $moduleName
		else
			echo "Cannot find the file /etc/init.d/$moduleName or /etc/systemd/system/$moduleName.service"
		fi
	fi
}

if [ $# -eq 0 ]
then
	help $0
fi

case "$1" in
	install|extract|list|changeGroups|activate) 
		"$@"
		;;
	*)
		help $0
		;;
esac

exit 0
__END_SCRIPT_TAG__
