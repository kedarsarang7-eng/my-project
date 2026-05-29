const fs = require('fs');

const data = JSON.parse(fs.readFileSync('c:\\desktop app\\Dukan_x\\my-backend\\.serverless\\cloudformation-template-update-stack.json', 'utf8'));
const resources = data.Resources;

// Build dependency graph
const graph = {};
for (const [resName, res] of Object.entries(resources)) {
    graph[resName] = new Set();

    // Check DependsOn
    if (res.DependsOn) {
        if (Array.isArray(res.DependsOn)) {
            res.DependsOn.forEach(d => graph[resName].add(d));
        } else {
            graph[resName].add(res.DependsOn);
        }
    }

    // Check Refs and GetAtts in Properties using JSON.stringify regex
    const str = JSON.stringify(res.Properties || {});
    const refRegex = /"Ref":"([^"]+)"/g;
    let match;
    while ((match = refRegex.exec(str)) !== null) {
        if (resources[match[1]]) {
            graph[resName].add(match[1]);
        }
    }

    const getAttRegex = /"Fn::GetAtt":\["([^"]+)"/g;
    while ((match = getAttRegex.exec(str)) !== null) {
        if (resources[match[1]]) {
            graph[resName].add(match[1]);
        }
    }
    // Sub
    const subRegex = /\$\{([^!:]+)(?:\.[^}]+)?\}/g;
    while ((match = subRegex.exec(str)) !== null) {
        if (resources[match[1]]) {
            graph[resName].add(match[1]);
        }
    }
}

// Find cycles using DFS
const visited = new Set();
const recursionStack = new Set();
const cycles = [];

function dfs(node, path) {
    visited.add(node);
    recursionStack.add(node);
    path.push(node);

    if (graph[node]) {
        for (const neighbor of graph[node]) {
            if (!visited.has(neighbor)) {
                if (dfs(neighbor, path)) return true;
            } else if (recursionStack.has(neighbor)) {
                const cycleStartIndex = path.indexOf(neighbor);
                cycles.push(path.slice(cycleStartIndex).join(' -> ') + ' -> ' + neighbor);
                return true;
            }
        }
    }

    recursionStack.delete(node);
    path.pop();
    return false;
}

for (const node of Object.keys(graph)) {
    if (!visited.has(node)) {
        if (dfs(node, [])) break;
    }
}

if (cycles.length > 0) {
    console.log("Circular dependency found:");
    console.log(cycles[0]);
} else {
    console.log("No circular dependency found by basic static analysis.");
}
