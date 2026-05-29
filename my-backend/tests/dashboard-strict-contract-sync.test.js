const fs = require('fs');
const path = require('path');

describe('Dashboard strict contract sync', () => {
  test('backend sees shared strict contract values', () => {
    const filePath = path.resolve(__dirname, '../../contracts/dashboard_strict_contract.json');
    expect(fs.existsSync(filePath)).toBe(true);

    const raw = fs.readFileSync(filePath, 'utf8');
    const contract = JSON.parse(raw);

    expect(contract.stalenessThresholdSec).toBeDefined();
    expect(contract.stalenessThresholdSec.dedicated).toBe(120);
    expect(contract.stalenessThresholdSec.shared).toBe(300);

    expect(contract.criticalMetricPolicy).toBeDefined();
    expect(contract.criticalMetricPolicy.dedicated).toBe('all_required');
    expect(contract.criticalMetricPolicy.shared).toBe('top_3_required');

    expect(Array.isArray(contract.dedicatedBusinessTypes)).toBe(true);
    expect(contract.dedicatedBusinessTypes).toEqual(
      expect.arrayContaining(['restaurant', 'clinic', 'petrolPump', 'pharmacy', 'autoParts', 'service']),
    );
  });
});
