// One place to reach the shinyreact runtime.
//
// React and every hook come off window.shinyreact rather than from npm, so
// this bundle shares the React instance that owns the hooks. Importing React
// from node_modules instead would load a second copy and break every hook.

const runtime = window.shinyreact;

export const React = runtime.React;
export const ReactDOM = runtime.ReactDOM;

export const useShinyInput = runtime.useShinyInput;
export const useShinyInputValue = runtime.useShinyInputValue;
export const useShinyOutputValue = runtime.useShinyOutputValue;
export const useShinyOutputStatus = runtime.useShinyOutputStatus;
export const useShinyInitialized = runtime.useShinyInitialized;
export const useShinyBusy = runtime.useShinyBusy;
export const useShinyMessageHandler = runtime.useShinyMessageHandler;

export const ShinyOutput = runtime.ShinyOutput;
export const ImageOutput = runtime.ImageOutput;
