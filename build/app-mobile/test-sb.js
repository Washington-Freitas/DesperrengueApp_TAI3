const { createClient } = require('@supabase/supabase-js');
const supabase = createClient('https://huyllczgvkrptzemztbo.supabase.co', 'sb_publishable_u92Qau7oG4KJ4X1WViTSDQ_hHD8jiVQ');

async function test() {
  try {
    const { data, error } = await supabase.from('_non_existent').select('*').limit(1);
    console.log('Test complete. Error:', error ? error.message : 'None');
  } catch(e) {
    console.log('Exception:', e.message);
  }
}
test();
