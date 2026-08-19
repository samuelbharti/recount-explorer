import { Loader2 } from "lucide-react";

import {
  React,
  useShinyBusy,
  useShinyInitialized,
  useShinyOutputValue,
} from "@/lib/shiny";
import { Badge } from "@/components/ui/field";
import { cn, formatCount } from "@/lib/utils";
import StudyBrowser from "@/views/StudyBrowser";
import StudyOverview from "@/views/StudyOverview";
import GeneExplorer from "@/views/GeneExplorer";
import PcaExplorer from "@/views/PcaExplorer";
import ExportView from "@/views/ExportView";
import type { CatalogStatus, StudyState } from "@/types";

const VIEWS = [
  { id: "browse", label: "Browse", element: StudyBrowser, needsStudy: false },
  { id: "overview", label: "Overview", element: StudyOverview, needsStudy: true },
  { id: "genes", label: "Genes", element: GeneExplorer, needsStudy: true },
  { id: "pca", label: "PCA", element: PcaExplorer, needsStudy: true },
  { id: "export", label: "Export", element: ExportView, needsStudy: true },
];

export default function App() {
  const ready = useShinyInitialized();
  const busy = useShinyBusy();
  const status = useShinyOutputValue<CatalogStatus>("catalog_status");
  const state = useShinyOutputValue<StudyState>("study_state");
  const [view, setView] = React.useState("browse");

  const loaded = state?.loaded === true;
  const Active = VIEWS.find((v) => v.id === view)?.element ?? StudyBrowser;

  // Every view is mounted the whole time. Unmounting one would tear down its
  // Shiny output bindings, so switching back would refetch a plot the server
  // already has.
  return (
    <div className="min-h-screen">
      <header className="border-b border-[var(--color-border-subtle)] bg-[var(--color-surface)]">
        <div className="mx-auto flex max-w-[1600px] flex-wrap items-center gap-x-6 gap-y-2 px-6 py-3">
          <div>
            <h1 className="text-lg font-semibold leading-tight">
              Recount Explorer
            </h1>
            <p className="text-xs text-[var(--color-ink-muted)]">
              {!ready
                ? "Connecting to the server…"
                : (status?.message ?? "Reading the study catalog…")}
            </p>
          </div>

          <nav className="flex flex-1 flex-wrap gap-1">
            {VIEWS.map((v) => {
              const disabled = v.needsStudy && !loaded;
              return (
                <button
                  key={v.id}
                  disabled={disabled}
                  onClick={() => setView(v.id)}
                  title={disabled ? "Load a study first" : undefined}
                  className={cn(
                    "rounded-md px-3 py-1.5 text-sm font-medium transition-colors",
                    view === v.id
                      ? "bg-[var(--color-accent-soft)] text-[var(--color-accent)]"
                      : "text-[var(--color-ink-muted)] hover:bg-[var(--color-surface-muted)]",
                    disabled && "cursor-not-allowed opacity-40 hover:bg-transparent",
                  )}
                >
                  {v.label}
                </button>
              );
            })}
          </nav>

          <div className="flex items-center gap-3">
            {busy && (
              <span className="flex items-center gap-1.5 text-xs text-[var(--color-ink-muted)]">
                <Loader2 className="h-3.5 w-3.5 animate-spin" />
                Working
              </span>
            )}
            {loaded && state.loaded && (
              <Badge className="border-[var(--color-accent)] bg-[var(--color-accent-soft)] text-[var(--color-accent)]">
                {state.project} · {formatCount(state.n_samples)} samples
              </Badge>
            )}
          </div>
        </div>
      </header>

      <main className="mx-auto max-w-[1600px] px-6 py-5">
        <Active />
      </main>

      <footer className="mx-auto max-w-[1600px] px-6 pb-8 text-xs text-[var(--color-ink-muted)]">
        Data from the{" "}
        <a
          className="text-[var(--color-accent)] hover:underline"
          href="https://rna.recount.bio/"
          target="_blank"
          rel="noopener"
        >
          recount3
        </a>{" "}
        project. Cite Wilks et al. 2021, Genome Biology 22:323.
      </footer>
    </div>
  );
}
