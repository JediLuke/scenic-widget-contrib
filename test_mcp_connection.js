const net = require('net');

// Connect to the MCP server
const client = new net.Socket();

client.connect(9999, 'localhost', () => {
    console.log('Connected to MCP server');
    
    // Send status command
    const statusCmd = JSON.stringify({
        action: "status"
    }) + "\n";
    
    client.write(statusCmd);
});

let commandCount = 0;

client.on('data', (data) => {
    console.log('Received:', data.toString());
    commandCount++;
    
    try {
        const response = JSON.parse(data.toString());
        
        if (commandCount === 1 && response.status === "ok") {
            // After status, get scenic graph
            const graphCmd = JSON.stringify({
                action: "get_scenic_graph"
            }) + "\n";
            
            client.write(graphCmd);
        } else if (commandCount === 2) {
            // After graph, take a screenshot
            const screenshotCmd = JSON.stringify({
                action: "take_screenshot",
                filename: "widget_workbench_screenshot.png"
            }) + "\n";
            
            client.write(screenshotCmd);
        } else if (commandCount === 3) {
            console.log('Screenshot taken!');
            client.end();
        }
    } catch (err) {
        console.error('Error parsing response:', err);
        client.end();
    }
});

client.on('error', (err) => {
    console.error('Connection error:', err);
});

client.on('close', () => {
    console.log('Connection closed');
});