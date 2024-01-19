#!/usr/bin/env bash

PROGNAME="Gammatech_test"
PORTNUM=23

CONNECT_MSG="Connect"
PING_MSG="Ping"
PONG_MSG="Pong"
BREAK_MSG="Break"
GET_MSG="Get"

TEMP_FILENAME="/usr/local/bin/temp"

PING_PONG_TIMEOUT_S=10
PING_PONG_COUNTER_S=0

save_connection_status () {
  rm -f $TEMP_FILENAME
  touch $TEMP_FILENAME
  echo $1 >> $TEMP_FILENAME
}

save_connection_status 0

# The first parameter is a name of a named pipe to write to.
# The second parameter is an input string.
write_to_named_pipe () {
  echo -e $2 "\r" >$1 &
}

check_ping_pong_timeout () {
  write_to_named_pipe $1 $PING_MSG
	
  while [[ $(echo "$PING_PONG_COUNTER_S < $PING_PONG_TIMEOUT_S" | bc -l) -eq 1 ]]; do
    PONG_FIFO_CONTENTS=$(cat 0<> $2 < $2)
    PONG_FIFO_CONTENTS_LENGTH=${#PONG_FIFO_CONTENTS}
    if [[ $(($PONG_FIFO_CONTENTS_LENGTH)) -eq 0 ]]; then
      PING_PONG_COUNTER_S=$(($PING_PONG_COUNTER_S + 1))
    else
      PING_PONG_COUNTER_S=0
    fi

    sleep 1 
    echo "$PING_PONG_COUNTER_S"
  done

  echo "$PROGNAME: Timeout."
  save_connection_status 0
}

clean_exit () {
  rm -f nc_stdout_fifo
  rm -f nc_stdin_fifo
  rm -f pong_fifo

  exit $1
}

mkfifo nc_stdout_fifo
mkfifo nc_stdin_fifo
mkfifo pong_fifo

echo "$PROGNAME: the service waits for a new connection."

cat <>nc_stdin_fifo | $(nc -l -p $PORTNUM >nc_stdout_fifo) &

while read -r line; do
  CONNECTION_ESTABLISHED=$(cat $TEMP_FILENAME)
  echo "$CONNECTION_ESTABLISHED"
  line=$(echo "$line" | tr -d '"\r\n')
  echo "$PROGNAME: $line"
  if [[ "$line" == "$CONNECT_MSG" ]]; then
    if [[ $(($CONNECTION_ESTABLISHED)) -eq 1 ]]; then
      echo "$PROGNAME: connection is already established."
      continue
    fi

    echo "$PROGNAME: connect request accepted. Ping-pong procedure started."
    save_connection_status 1
    check_ping_pong_timeout nc_stdin_fifo pong_fifo &
  elif [[ "$line" == "$PONG_MSG" ]]; then
    if [[ $(($CONNECTION_ESTABLISHED)) -eq 0 ]]; then
      echo "$PROGNAME: there is no any connection established."
      continue
    else
      echo 1 > pong_fifo
    fi
  else
    echo "$PROGNAME: unknown command."
  fi
done <nc_stdout_fifo




clean_exit 0
