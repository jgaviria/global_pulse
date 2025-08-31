// Test hook to verify LiveView hooks are working
export const TestHook = {
  mounted() {
    console.log('TEST HOOK MOUNTED - LiveView hooks are working!');
    this.el.innerHTML = '<div style="color: red; font-weight: bold;">TEST HOOK WORKING!</div>';
  },
  
  updated() {
    console.log('TEST HOOK UPDATED');
  }
};