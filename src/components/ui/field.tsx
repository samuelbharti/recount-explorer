import { React } from "@/lib/shiny";
import { cn } from "@/lib/utils";

const CONTROL = [
  "w-full rounded-md border border-[var(--color-border-subtle)]",
  "bg-[var(--color-surface)] px-3 py-1.5 text-sm",
  "focus:outline-2 focus:outline-offset-0 focus:outline-[var(--color-accent)]",
].join(" ");

export function Input({
  className,
  ...props
}: React.InputHTMLAttributes<HTMLInputElement>) {
  return <input className={cn(CONTROL, className)} {...props} />;
}

export function Select({
  className,
  ...props
}: React.SelectHTMLAttributes<HTMLSelectElement>) {
  return <select className={cn(CONTROL, className)} {...props} />;
}

export function Label({
  className,
  ...props
}: React.LabelHTMLAttributes<HTMLLabelElement>) {
  return (
    <label
      className={cn(
        "mb-1 block text-xs font-medium uppercase tracking-wide",
        "text-[var(--color-ink-muted)]",
        className,
      )}
      {...props}
    />
  );
}

export function Badge({
  className,
  ...props
}: React.HTMLAttributes<HTMLSpanElement>) {
  return (
    <span
      className={cn(
        "inline-flex items-center rounded-full border",
        "border-[var(--color-border-subtle)] bg-[var(--color-surface-muted)]",
        "px-2.5 py-0.5 text-xs font-medium",
        className,
      )}
      {...props}
    />
  );
}

/** Shown wherever a view needs a study but none is loaded. */
export function EmptyState({ message }: { message: string }) {
  return (
    <div
      className={cn(
        "flex min-h-56 items-center justify-center rounded-lg border",
        "border-dashed border-[var(--color-border-subtle)]",
        "px-6 text-center text-sm text-[var(--color-ink-muted)]",
      )}
    >
      {message}
    </div>
  );
}
