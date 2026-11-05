{{flutter_js}}
{{flutter_build_config}}

_flutter.loader.load({
  onEntrypointLoaded: async function(engineInitializer) {
    if (typeof window.dismissDilSeFallback === 'function') {
      window.dismissDilSeFallback();
    }
    const appRunner = await engineInitializer.initializeEngine();
    await appRunner.runApp();
  }
});
