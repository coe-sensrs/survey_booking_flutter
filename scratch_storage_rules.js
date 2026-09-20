const fs = require('fs');
const rules = fs.readFileSync('storage.rules', 'utf8');

async function main() {
  const resp = await fetch('http://127.0.0.1:9199/internal/setRules', {
    method: 'PUT',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ rules: { files: [{ name: 'storage.rules', content: rules }] } })
  });
  console.log('Status:', resp.status);
  console.log('Response:', await resp.text());
}
main().catch(console.error);
