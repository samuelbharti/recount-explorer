import { React } from "@/lib/shiny";
import { cn } from "@/lib/utils";

/** A grey block standing in for content that has not arrived. */
export function Skeleton({
  className,
  ...props
}: React.HTMLAttributes<HTMLDivElement>) {
  return (
    <div
      className={cn(
        "animate-pulse rounded bg-[var(--color-border-subtle)]",
        className,
      )}
      {...props}
    />
  );
}

/**
 * Placeholder for the results table.
 *
 * A row-shaped skeleton rather than a spinner, so the layout does not jump
 * when the real rows arrive and the wait reads as "nearly there".
 */
export function TableSkeleton({ rows = 8 }: { rows?: number }) {
  const widths = ["w-24", "w-16", "w-12", "w-14", "w-2/5"];
  return (
    <div className="divide-y divide-[var(--color-border-subtle)]">
      {Array.from({ length: rows }, (_, i) => (
        <div key={i} className="flex items-center gap-4 px-3 py-2.5">
          {widths.map((w, j) => (
            <Skeleton key={j} className={cn("h-3", w)} />
          ))}
        </div>
      ))}
    </div>
  );
}
