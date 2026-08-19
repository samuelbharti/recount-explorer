import { React, ShinyOutput } from "@/lib/shiny";
import { cn } from "@/lib/utils";

// ShinyOutput renders a bare element with the given id and spreads the rest of
// the props onto it. It does not know what kind of output it is. Shiny binds
// its outputs by CSS class, so the class is what makes a div a plot and an
// anchor a download. Read out of the shipped bundle:
//
//   function ShinyOutput({ id, tagName = "div", namespace, ...rest }) { ... }
//
// These two wrappers exist so no view has to remember the class names.

/** A server-rendered ggplot2 figure, bound by Shiny's plot output binding. */
export function PlotOutput({
  id,
  height,
  className,
}: {
  id: string;
  height: number;
  className?: string;
}) {
  return (
    <ShinyOutput
      id={id}
      className={cn("shiny-plot-output w-full", className)}
      style={{ height }}
    />
  );
}

/** A downloadHandler link. Shiny fills in href once the binding attaches. */
export function DownloadLink({
  id,
  children,
  className,
}: {
  id: string;
  children: React.ReactNode;
  className?: string;
}) {
  return (
    <ShinyOutput
      id={id}
      tagName="a"
      className={cn("shiny-download-link", className)}
      href=""
      target="_blank"
    >
      {children}
    </ShinyOutput>
  );
}
