const net = require('net');

class SocketProxy {
    socket;

    constructor(port) {
        net.createServer((socket) => {
            this.socket = socket;
            console.log("Connected");
        }).listen(port);
    }

    proxyRequest(id) {
        if (this.socket) {
            console.log("Sending ID " + id + " to client")
            this.socket.write(id + 'z'); // 'z' = request delimiter
        }
    }
}

module.exports = SocketProxy;