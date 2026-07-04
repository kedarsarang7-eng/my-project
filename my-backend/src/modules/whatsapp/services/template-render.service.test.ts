// ============================================================================
// Unit tests for template-render.service.ts (Task 7.1)
// ============================================================================

import { render, sanitize, RenderResult, TemplateInput, RenderPayload } from './template-render.service';

describe('template-render.service', () => {
  describe('render()', () => {
    it('substitutes all placeholders with matching payload values', () => {
      const template: TemplateInput = {
        body: 'Hello {{customer.name}}, your invoice #{{invoiceId}} for {{amount}} is ready.',
        placeholders: ['customer.name', 'invoiceId', 'amount'],
      };
      const payload: RenderPayload = {
        customer: { name: 'Rajesh Kumar' },
        invoiceId: 'INV-001',
        amount: '₹5,000',
      };

      const result = render(template, payload);

      expect(result.success).toBe(true);
      if (result.success) {
        expect(result.text).toBe('Hello Rajesh Kumar, your invoice #INV-001 for ₹5,000 is ready.');
      }
    });

    it('converts numbers and booleans to strings', () => {
      const template: TemplateInput = {
        body: 'Amount: {{amount}} paise, paid: {{paid}}',
        placeholders: ['amount', 'paid'],
      };
      const payload: RenderPayload = { amount: 50000, paid: true };

      const result = render(template, payload);

      expect(result.success).toBe(true);
      if (result.success) {
        expect(result.text).toBe('Amount: 50000 paise, paid: true');
      }
    });

    it('fails closed when ANY placeholder is unresolved', () => {
      const template: TemplateInput = {
        body: 'Dear {{customer.name}}, your order {{orderId}} ships on {{shipDate}}.',
        placeholders: ['customer.name', 'orderId', 'shipDate'],
      };
      const payload: RenderPayload = {
        customer: { name: 'Amit' },
        orderId: 'ORD-42',
        // shipDate is missing
      };

      const result = render(template, payload);

      expect(result.success).toBe(false);
      if (!result.success) {
        expect(result.missingPlaceholders).toContain('shipDate');
        expect(result.error).toContain('{{shipDate}}');
        expect(result.error).toContain('fail-closed');
      }
    });

    it('fails closed when payload value is null', () => {
      const template: TemplateInput = {
        body: 'Hello {{name}}',
        placeholders: ['name'],
      };
      const payload: RenderPayload = { name: null };

      const result = render(template, payload);

      expect(result.success).toBe(false);
      if (!result.success) {
        expect(result.missingPlaceholders).toContain('name');
      }
    });

    it('fails closed when payload value is undefined', () => {
      const template: TemplateInput = {
        body: 'Hello {{name}}',
        placeholders: ['name'],
      };
      const payload: RenderPayload = { name: undefined };

      const result = render(template, payload);

      expect(result.success).toBe(false);
      if (!result.success) {
        expect(result.missingPlaceholders).toContain('name');
      }
    });

    it('fails closed when payload value is an object (non-scalar)', () => {
      const template: TemplateInput = {
        body: 'Data: {{info}}',
        placeholders: ['info'],
      };
      const payload: RenderPayload = { info: { nested: 'value' } };

      const result = render(template, payload);

      expect(result.success).toBe(false);
      if (!result.success) {
        expect(result.missingPlaceholders).toContain('info');
      }
    });

    it('fails closed when payload value is an array (non-scalar)', () => {
      const template: TemplateInput = {
        body: 'Items: {{items}}',
        placeholders: ['items'],
      };
      const payload: RenderPayload = { items: ['a', 'b', 'c'] };

      const result = render(template, payload);

      expect(result.success).toBe(false);
      if (!result.success) {
        expect(result.missingPlaceholders).toContain('items');
      }
    });

    it('also checks undeclared placeholders found in the body', () => {
      const template: TemplateInput = {
        body: 'Hello {{name}}, your code is {{code}}',
        placeholders: ['name'], // 'code' is not declared but is in the body
      };
      const payload: RenderPayload = { name: 'Test' };

      const result = render(template, payload);

      // Should fail because {{code}} in body has no payload value
      expect(result.success).toBe(false);
      if (!result.success) {
        expect(result.missingPlaceholders).toContain('code');
      }
    });

    it('handles templates with no placeholders', () => {
      const template: TemplateInput = {
        body: 'Thank you for your purchase!',
        placeholders: [],
      };
      const payload: RenderPayload = {};

      const result = render(template, payload);

      expect(result.success).toBe(true);
      if (result.success) {
        expect(result.text).toBe('Thank you for your purchase!');
      }
    });

    it('handles deeply nested payload paths', () => {
      const template: TemplateInput = {
        body: 'Invoice from {{business.address.city}}',
        placeholders: ['business.address.city'],
      };
      const payload: RenderPayload = {
        business: { address: { city: 'Mumbai' } },
      };

      const result = render(template, payload);

      expect(result.success).toBe(true);
      if (result.success) {
        expect(result.text).toBe('Invoice from Mumbai');
      }
    });

    it('reports multiple missing placeholders in sorted order', () => {
      const template: TemplateInput = {
        body: '{{z_last}} {{a_first}} {{m_middle}}',
        placeholders: ['z_last', 'a_first', 'm_middle'],
      };
      const payload: RenderPayload = {};

      const result = render(template, payload);

      expect(result.success).toBe(false);
      if (!result.success) {
        expect(result.missingPlaceholders).toEqual(['a_first', 'm_middle', 'z_last']);
      }
    });
  });

  describe('sanitize()', () => {
    it('strips C0 control characters except tab/newline/CR', () => {
      const input = 'Hello\x00World\x01!\x07\t\n';
      const result = sanitize(input);
      expect(result).toBe('HelloWorld!\t\n');
    });

    it('escapes HTML/XML angle brackets to fullwidth equivalents', () => {
      const input = '<script>alert("xss")</script>';
      const result = sanitize(input);
      expect(result).toContain('\uFF1C'); // fullwidth <
      expect(result).toContain('\uFF1E'); // fullwidth >
      expect(result).not.toContain('<');
      expect(result).not.toContain('>');
    });

    it('escapes ampersands to prevent HTML entity injection', () => {
      const input = '&amp; &lt; &#x27;';
      const result = sanitize(input);
      expect(result).not.toMatch(/&(?!$)/); // no raw ampersands (except possibly at end)
      expect(result).toContain('\uFF06'); // fullwidth &
    });

    it('neutralizes WhatsApp formatting markers', () => {
      const input = '*bold* _italic_ ~strike~ `code`';
      const result = sanitize(input);
      // Each marker should be prefixed with ZWNJ (\u200C)
      expect(result).not.toBe(input);
      expect(result).toContain('\u200C*');
      expect(result).toContain('\u200C_');
      expect(result).toContain('\u200C~');
      expect(result).toContain('\u200C`');
    });

    it('removes bidirectional override characters', () => {
      const input = 'Normal\u202Eoverride\u202Ctext';
      const result = sanitize(input);
      expect(result).not.toContain('\u202E');
      expect(result).not.toContain('\u202C');
    });

    it('removes zero-width characters', () => {
      const input = 'hid\u200Bden\u200Ctext\u200D!';
      const result = sanitize(input);
      // Zero-width chars (ZWS, ZWNJ, ZWJ) are stripped before formatting escape
      expect(result).toBe('hiddentext!');
    });

    it('preserves safe text unchanged (aside from zero-width joiner in formatting)', () => {
      const input = 'Hello Rajesh, your bill is 5000 paise.';
      const result = sanitize(input);
      expect(result).toBe('Hello Rajesh, your bill is 5000 paise.');
    });

    it('handles empty string', () => {
      expect(sanitize('')).toBe('');
    });

    it('strips C1 control characters (0x80-0x9F)', () => {
      const input = 'Test\x80\x85\x9F end';
      const result = sanitize(input);
      expect(result).toBe('Test end');
    });
  });

  describe('render() with sanitization integration', () => {
    it('sanitizes substituted values containing HTML', () => {
      const template: TemplateInput = {
        body: 'Customer: {{name}}',
        placeholders: ['name'],
      };
      const payload: RenderPayload = { name: '<b>Evil</b>' };

      const result = render(template, payload);

      expect(result.success).toBe(true);
      if (result.success) {
        expect(result.text).not.toContain('<');
        expect(result.text).not.toContain('>');
        expect(result.text).toContain('\uFF1C');
        expect(result.text).toContain('\uFF1E');
      }
    });

    it('sanitizes substituted values containing control characters', () => {
      const template: TemplateInput = {
        body: 'Note: {{note}}',
        placeholders: ['note'],
      };
      const payload: RenderPayload = { note: 'Line1\x00\x01Line2' };

      const result = render(template, payload);

      expect(result.success).toBe(true);
      if (result.success) {
        expect(result.text).toBe('Note: Line1Line2');
        expect(result.text).not.toMatch(/[\x00-\x08]/);
      }
    });

    it('does not sanitize the template body itself, only substituted values', () => {
      // The template body may contain formatting that the business intends.
      // Only substituted user data gets sanitized.
      const template: TemplateInput = {
        body: '*Hello* {{name}}, your invoice is ready.',
        placeholders: ['name'],
      };
      const payload: RenderPayload = { name: 'Priya' };

      const result = render(template, payload);

      expect(result.success).toBe(true);
      if (result.success) {
        // The *Hello* from template body is preserved as-is
        expect(result.text).toContain('*Hello*');
        expect(result.text).toContain('Priya');
      }
    });
  });
});
