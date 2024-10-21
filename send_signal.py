import socket
import random

# Set up TCP/IP socket
server_socket = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
server_socket.bind(('0.0.0.0', 8080))
server_socket.listen(1)

while True:
    # Accept incoming connection
    client_socket, client_address = server_socket.accept()
    
    # Handle client request
    data = client_socket.recv(1024)
    
    # Process request and send response
    # Example: Send temperature reading
    temperature = random.randint(0,10)
    response = f'Temperature: {temperature}°C'
    client_socket.send(response.encode())
    
    # Close connection
    client_socket.close()
