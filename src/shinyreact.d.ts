// Types for the runtime that the shinyreact R package puts on window.
//
// The bundle does not import React from npm. Both React and the hooks come
// from window.shinyreact, so that this code and the hooks share one React
// instance. Two copies of React would make every useState throw.
//
// The names here were read from the shipped bundle
// (shinyreact/lib/shiny/shinyreact.js), not from the documentation.

import type * as ReactNamespace from "react";
import type * as ReactDOMNamespace from "react-dom/client";

export type ShinyOutputStatus = "idle" | "recalculating" | "error";

declare global {
  interface Window {
    shinyreact: {
      React: typeof ReactNamespace;
      ReactDOM: typeof ReactDOMNamespace;

      /** Two-way binding to a Shiny input. Returns [value, setValue]. */
      useShinyInput<T>(
        id: string,
        defaultValue: T,
        options?: { priority?: "event" | "deferred"; debounceMs?: number },
      ): [T, (value: T) => void];

      /** Read-only view of a Shiny input's current value. */
      useShinyInputValue<T>(id: string): T | undefined;

      /** The value of a server-side reactive_output(), by id. */
      useShinyOutputValue<T>(id: string, defaultValue?: T): T | undefined;

      /** Whether that output is currently recalculating on the server. */
      useShinyOutputStatus(id: string): ShinyOutputStatus;

      /** True once Shiny has connected and the session is live. */
      useShinyInitialized(): boolean;

      /** True while Shiny is busy anywhere in the session. */
      useShinyBusy(): boolean;

      /** Handle a message sent from R with send_message(session, type, data). */
      useShinyMessageHandler<T>(type: string, handler: (data: T) => void): void;

      /** Renders a bare element with this id and spreads the remaining props
       *  onto it, then calls Shiny.bindAll on its parent. It does not know
       *  what kind of output it is: Shiny binds by CSS class, so the caller
       *  supplies shiny-plot-output, shiny-download-link and so on. */
      ShinyOutput: ReactNamespace.ComponentType<{
        id: string;
        tagName?: string;
        namespace?: string;
        className?: string;
        style?: ReactNamespace.CSSProperties;
        children?: ReactNamespace.ReactNode;
        [key: string]: unknown;
      }>;

      /** Renders an image output, the usual home for a ggplot2 renderPlot. */
      ImageOutput: ReactNamespace.ComponentType<{
        id: string;
        className?: string;
        style?: ReactNamespace.CSSProperties;
        [key: string]: unknown;
      }>;

      /** Namespaces the ids used by everything inside it, for Shiny modules. */
      ShinyModuleProvider: ReactNamespace.ComponentType<{
        namespace: string;
        children: ReactNamespace.ReactNode;
      }>;
    };
  }
}

export {};
