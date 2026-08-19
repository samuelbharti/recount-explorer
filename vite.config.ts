import path from "node:path";
import { fileURLToPath } from "node:url";

import react from "@vitejs/plugin-react";
import tailwindcss from "@tailwindcss/vite";
import { defineConfig } from "vite";

const dirname = path.dirname(fileURLToPath(import.meta.url));

// React and ReactDOM are externalized and taken from window.shinyreact at
// runtime. The bundle has to share the React instance that owns the shinyreact
// hooks, otherwise the hooks run against a second copy of React and every
// useState throws.
export default defineConfig({
  define: {
    "process.env.NODE_ENV": JSON.stringify("production"),
  },
  // Classic JSX, not the automatic runtime. The automatic runtime emits an
  // import of react/jsx-runtime, which resolves out of node_modules and pulls
  // in a second copy of React. Two Reacts means the hooks from
  // window.shinyreact write to one dispatcher while the components read the
  // other, and every useState throws. Classic compiles JSX to
  // React.createElement against the React each file imports from @/lib/shiny.
  plugins: [
    react({ jsxRuntime: "classic" }),
    tailwindcss(),
  ],
  resolve: {
    alias: { "@": path.resolve(dirname, "src") },
  },
  build: {
    outDir: "www",
    emptyOutDir: false,
    cssCodeSplit: false,
    lib: {
      entry: path.resolve(dirname, "src/ui.tsx"),
      formats: ["iife"],
      name: "RecountExplorer",
      fileName: () => "app.js",
    },
    rollupOptions: {
      external: ["react", "react-dom", "react-dom/client"],
      output: {
        assetFileNames: "style.css",
        globals: {
          react: "window.shinyreact.React",
          "react-dom": "window.shinyreact.ReactDOM",
          "react-dom/client": "window.shinyreact.ReactDOM",
        },
      },
    },
  },
});
