#!/usr/bin/env bash

PROGNAME="Gammatech_test"
PORTNUM=23

IPV4_ADDRESS=$(ip a | grep "inet 192.168." | cut -d ' ' -f 6)

TEMP_FOLDER_PATH="/tmp/$PROGNAME"

mkdir $TEMP_FOLDER_PATH

NC_STDIN_FIFO="$TEMP_FOLDER_PATH/nc_stdin_fifo"
NC_STDOUT_FIFO="$TEMP_FOLDER_PATH/nc_stdout_fifo"
PONG_FIFO="$TEMP_FOLDER_PATH/pong_fifo"
TEMP_FILENAME="$TEMP_FOLDER_PATH/temp"

mkfifo $NC_STDIN_FIFO
mkfifo $NC_STDOUT_FIFO
mkfifo $PONG_FIFO

CONNECT_MSG="Connect"
PING_MSG="Ping"
PONG_MSG="Pong"
BREAK_MSG="Break"
GET_MSG="Get"

HOSTNAME=$(hostname)
OS_VERSION=$(cat /etc/os-release | grep PRETTY_NAME | cut -d '"' -f 2)
SERIAL_NUMBER=$(cat /proc/cpuinfo | grep Serial | cut -d ' ' -f 2)
DESCRIPTION="Some description."

PING_PONG_TIMEOUT_S=10
PING_PONG_COUNTER_S=0

# The first parameter is connection status: 0 -- there is no active connection,
# 1 -- connection established.
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

# The first parameter is netcat stdin.
# The second parameter is a pipe from which "Pong" event should be expected.
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
  done

  echo "$PROGNAME: Timeout."
  save_connection_status 0
}

echo "$PROGNAME: the service waits for a new connection on $IPV4_ADDRESS."

cat <>$NC_STDIN_FIFO | $(nc -l -p $PORTNUM >$NC_STDOUT_FIFO) &

while read -r line; do
  CONNECTION_ESTABLISHED=$(cat $TEMP_FILENAME)
  line=$(echo "$line" | tr -d '"\r\n')
  echo "$PROGNAME: $line"
  if [[ "$line" == "$CONNECT_MSG" ]]; then
    if [[ $(($CONNECTION_ESTABLISHED)) -eq 1 ]]; then
      echo "$PROGNAME: connection is already established."
      continue
    fi

    echo "$PROGNAME: connect request accepted. Ping-pong procedure started."
    save_connection_status 1
    check_ping_pong_timeout $NC_STDIN_FIFO $PONG_FIFO &
  elif [[ "$line" == "$PONG_MSG" ]]; then
    if [[ $(($CONNECTION_ESTABLISHED)) -eq 0 ]]; then
      echo "$PROGNAME: there is no any connection established."
      continue
    else
      echo 1 > $PONG_FIFO
    fi
  elif [[ "$line" == "$BREAK_MSG" ]]; then
    exit 0
  elif [[ "$line" == "$GET_MSG" ]]; then
    if [[ $(($CONNECTION_ESTABLISHED)) -eq 1 ]]; then
      write_to_named_pipe $NC_STDIN_FIFO "Device Name: $HOSTNAME"
      write_to_named_pipe $NC_STDIN_FIFO "OS Version: $OS_VERSION"
      write_to_named_pipe $NC_STDIN_FIFO "Serial Number: $SERIAL_NUMBER"
      write_to_named_pipe $NC_STDIN_FIFO "Description: $DESCRIPTION"
    else
      echo "$PROGNAME: there is no active connection."
    fi
  else
    echo "$PROGNAME: unknown command."
  fi
done <$NC_STDOUT_FIFO

exit 0
