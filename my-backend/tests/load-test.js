const autocannon = require('autocannon');

/**
 * Basic Load Test using Autocannon
 * Simulates 100 concurrent connections over 30 seconds
 * against the unauthenticated endpoints to test API Gateway and Lambda scaling.
 */

async function runTest() {
    const url = process.env.TEST_URL || 'http://localhost:8000/admin/status';
    
    console.log(`Starting load test against: ${url}`);
    
    const instance = autocannon({
        url,
        connections: 100, // Concurrent connections
        pipelining: 1,
        duration: 30, // Test duration in seconds
        method: 'GET',
        headers: {
            'content-type': 'application/json',
            'user-agent': 'Autocannon/LoadTester'
        }
    }, (err, result) => {
        if (err) {
            console.error('Test failed:', err);
            return;
        }
        
        console.log('\n--- Load Test Results ---');
        console.log(`Requests/sec: ${result.requests.average}`);
        console.log(`Latency (p99): ${result.latency.p99} ms`);
        console.log(`Errors: ${result.errors}`);
        console.log(`Timeouts: ${result.timeouts}`);
        console.log('-------------------------');
        
        if (result.errors > 0 || result.timeouts > 0) {
            console.warn('⚠️ WARNING: System threw errors or timed out under load. Check CloudWatch/RDS Connections.');
        } else {
            console.log('✅ PASS: System remained stable under load.');
        }
    });

    autocannon.track(instance, { renderProgressBar: true });
}

runTest();
