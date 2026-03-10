{{flutter_js}}
{{flutter_build_config}}

// Set a timeout to destory the HTML loading widget and run flutter.
_flutter.loader.load({
    onEntrypointLoaded: async function(engineInitializer) {
        window.addEventListener('flutter-first-frame',() => {
            const loader = document.getElementById("loading-screen");
            if (loader) {
                loader.remove();
            }
        });

        const appRunner = await engineInitializer.initializeEngine();
        await appRunner.runApp();
    }
});
