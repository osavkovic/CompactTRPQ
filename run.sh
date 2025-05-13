#!/bin/bash

# this code assumes an environment variable PSQL that is the the psql command with the connection parameters

for gran in 1 2; do # add desired domain scaling factor k here

  echo "----------------------------------------------------------------------------" >>out.txt
  echo "-- Granularity $gran times the raw granularity " >>out.txt
  echo "----------------------------------------------------------------------------" >>out.txt

  cat template_data_setup.sql >data_setup.sql
  sed -i "s/???/${gran}/g" data_setup.sql
  $PSQL -f data_setup.sql >>out.txt

  for i in 1 2; do # add desired duration x here
    cat template_contact_-X_0.sql >contact_-${i}_0.sql
    sed -i "s/???/${i}/g" contact_-${i}_0.sql
    sed -i "s/?!?/${gran}/g" contact_-${i}_0.sql

    echo "----------------------------------------------------------------------------" >>out.txt
    echo "-- (positive = true)/T[-${i}, 0]/F/meets/ " >>out.txt
    echo "----------------------------------------------------------------------------" >>out.txt
    $PSQL -f contact_-${i}_0.sql >>out.txt
  done
done
