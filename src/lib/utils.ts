import { clsx, type ClassValue } from "clsx";
import { twMerge } from "tailwind-merge";

/** Merge class names, with later Tailwind utilities winning over earlier. */
export function cn(...inputs: ClassValue[]) {
  return twMerge(clsx(inputs));
}

/** 18998 becomes "18,998". */
export function formatCount(n: number | undefined | null): string {
  if (n === undefined || n === null || Number.isNaN(n)) return "0";
  return n.toLocaleString("en-US");
}
