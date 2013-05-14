
DIR=`dirname $(realpath $0)`
TEMPLATE=$DIR/backend_sql.template
if [ ! -e $TEMPLATE ]; then
    echo "Cannot find file $TEMPLATE"
    exit
fi

while [ ! -d .git ]; do
    cd ..
    if [ `pwd` = "/" ]; then
        echo "Couldn't find root keystone directory"
        exit
    fi
done

KEYSTONEDBSERVER=localhost
KEYSTONEUSER=keystonetest
KEYSTONEPASS=keystonetest
KEYSTONEDB=keystonetest

case $1 in
    "p" | "pg" | "postgres" )
        NAME=postgres

        # CREATE USER keystonetest WITH PASSWORD 'keystonetest';
        # CREATE DATABASE keystonetest;
        # GRANT ALL PRIVILEGES ON DATABASE keystonetest TO keystonetest;

        export PGPASSWORD=$KEYSTONEPASS
        psql -U $KEYSTONEUSER -d $KEYSTONEDB -At -c "select 'drop table if exists \"' || tablename || '\" cascade;' from pg_tables where schemaname = 'public';" | psql -U $KEYSTONEUSER -d $KEYSTONEDB &> /dev/null || { echo "Failed to clear database"; exit 1; }
        CONNECTION="postgresql://$KEYSTONEUSER:$KEYSTONEPASS@$KEYSTONEDBSERVER/$KEYSTONEDB?client_encoding=utf8"
        unset PGPASSWORD
        ;;
    "m" | "my" | "mysql" )
        NAME=mysql

        # CREATE USER keystonetest;
        # CREATE DATABASE keystonetest;
        # grant all on keystonetest.* to keystonetest@localhost identified by 'keystonetest'

        TABLES=`mysql -u$KEYSTONEUSER -p$KEYSTONEPASS --batch --skip-column-names -e "SELECT concat('DROP TABLE ', table_name, ';') FROM information_schema.tables WHERE table_schema = '$KEYSTONEDB'"`
        if [ -n "$TABLES" ]; then
            mysql -u$KEYSTONEUSER -p$KEYSTONEPASS -D $KEYSTONEDB -e "SET FOREIGN_KEY_CHECKS = 0; $TABLES SET FOREIGN_KEY_CHECKS = 1;"
        fi
        CONNECTION="mysql://$KEYSTONEUSER:$KEYSTONEPASS@$KEYSTONEDBSERVER/$KEYSTONEDB?charset=utf8"
        ;;
    "s" | "sqlite" )
        NAME=sqlite
        CONNECTION="sqlite://"
        ;;
    "f" | "file" )
        rm ./keystonedb.db
        NAME=file
        CONNECTION="sqlite:///keystone.db"
        ;;
    "a" | "all" )
        shift
        echo "*** SQLITE ***"
        $0 sqlite $@
        echo "*** MYSQL ***"
        $0 mysql $@
        echo "*** POSTGRES ***"
        $0 postgres $@
        echo "*** DONE ***"
        exit
        ;;
    * )
        echo "Please pick postgres, mysql or sqlite for first parameter"
        exit
        ;;
esac

shift
sed -e "s;%CONNECTION%;$CONNECTION;" $TEMPLATE > tests/backend_sql.conf

# rm -rf vendor
find tests/ -name *.pyc | xargs rm
find keystone/ -name *.pyc | xargs rm

# TESTNAME=
# if [ ! -z $2 ]; then
# # test_sql_upgrade:SqlUpgradeTests
#     TESTNAME=$2
# fi

nosetests -s --openstack-stdout $@ 2>&1 | tee test_$NAME.log test_last.log
VAL=$?

git checkout tests/backend_sql.conf

exit $VAL
