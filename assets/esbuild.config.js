const esbuild = require('esbuild');

esbuild.build({
    entryPoints: ['js/app.js'],
    bundle: true,
    outdir: '../priv/static/assets',
    minify: true,
    sourcemap: true,
}).catch(() => process.exit(1));