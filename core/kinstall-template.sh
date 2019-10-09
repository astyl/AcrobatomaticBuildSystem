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

    activate : activate a kernel module
      mandatory arg : module name

    help : display help info
EOF
exit 0
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

	mkdir -p "$PREFIX/lib/modules/$PKVERSION/drast"
	tail -n +$SKIP "$THIS" | tar -xvz --overwrite -C "$PREFIX/lib/modules/$PKVERSION/drast" --strip-components=2 lib/modules
    mkdir -p "$PREFIX/etc/drast"
    tail -n +$SKIP "$THIS" | tar -xvz -C "$PREFIX/etc/drast" --strip-components=2 --keep-old-files --wildcards etc/drast/*.conf
    mkdir -p "$PREFIX/etc/drast/bin"
    mkdir -p "$PREFIX/etc/drast/services"
    tail -n +$SKIP "$THIS" | tar -xvz --overwrite -C "$PREFIX/etc/drast" --strip-components=2 etc/drast/services etc/drast/bin
    mkdir -p "$PREFIX/etc/init.d"
    tail -n +$SKIP "$THIS" | tar -xvz --overwrite -C "$PREFIX/etc/init.d" --strip-components=2 etc/init.d 
    
    if [ -d "$PREFIX/etc/drast/bin" ]; then
        chmod 750 $PREFIX/etc/drast/bin/*
    fi
	if [ "$(which systemd)" != "" ]; then
	    echo "Installation des drivers pour systemd"
        if [ -d "$PREFIX/etc/drast/services" ]; then
            mkdir -p "$PREFIX/lib/systemd/system"
            for serviceFile in `ls $PREFIX/etc/drast/services/*.service`; do
                echo "Linking $serviceFile into $PREFIX/lib/systemd/system"
                chmod 750 $serviceFile
                ln -srf "$serviceFile" "$PREFIX/lib/systemd/system/"
            done
        fi
    else
        echo "Installation des drivers avec init.d"
        if [ -d "$PREFIX/etc/drast/bin" ]; then
            for execFile in `ls "$PREFIX/etc/drast/bin"`; do
                echo "Linking $execFile into init.d"
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
    tail -n +$SKIP "$THIS" | tar -tz etc/drast/bin | sed 's/etc\/drast\/bin\/\(.*\)/\1/g'
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
	        chmod 750 /lib/systemd/system/$moduleName.service
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
	install|extract|list|activate) 
		"$@"
		;;
	*)
		help $0
		;;
esac

exit 0
__END_SCRIPT_TAG__
