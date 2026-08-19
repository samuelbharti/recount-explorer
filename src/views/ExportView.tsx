import { FileDown } from "lucide-react";

import { React, useShinyOutputValue } from "@/lib/shiny";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { EmptyState } from "@/components/ui/field";
import { DownloadLink } from "@/components/ui/shiny-io";
import type { StudyState } from "@/types";

// Shiny owns each download link: downloadHandler fills in the href once the
// binding attaches, so ShinyOutput mounts the anchor rather than React
// rendering its own.
const DOWNLOADS: Array<{ id: string; label: string; hint: string }> = [
  {
    id: "download_rse",
    label: "RangedSummarizedExperiment (.rds)",
    hint: "Counts, metadata and gene annotation in one R object.",
  },
  {
    id: "download_expression",
    label: "log2 CPM matrix (.csv.gz)",
    hint: "Genes by samples, the same values every view plots.",
  },
  {
    id: "download_metadata",
    label: "Sample metadata (.csv)",
    hint: "Every colData column, list columns flattened.",
  },
  {
    id: "download_script",
    label: "Reproduction script (.R)",
    hint: "Repeats this session with recount3 and ggplot2 only.",
  },
  {
    id: "download_gene_pdf",
    label: "Gene plot (.pdf)",
    hint: "Exactly the figure on the Genes view.",
  },
  {
    id: "download_pca_pdf",
    label: "PCA plot (.pdf)",
    hint: "Exactly the figure on the PCA view.",
  },
];

export default function ExportView() {
  const state = useShinyOutputValue<StudyState>("study_state");
  const script = useShinyOutputValue<string>("reproduction_script");

  if (!state?.loaded) {
    return <EmptyState message="Load a study from the Browse view first." />;
  }

  return (
    <div className="grid gap-4 lg:grid-cols-[360px_1fr]">
      <Card className="h-fit">
        <CardHeader>
          <CardTitle>Downloads</CardTitle>
        </CardHeader>
        <CardContent className="space-y-3">
          {DOWNLOADS.map((d) => (
            <div
              key={d.id}
              className="rounded-md border border-[var(--color-border-subtle)] p-3"
            >
              <div className="flex items-center gap-2 text-sm font-medium">
                <FileDown className="h-4 w-4 text-[var(--color-accent)]" />
                <DownloadLink
                  id={d.id}
                  className="text-[var(--color-accent)] hover:underline"
                >
                  {d.label}
                </DownloadLink>
              </div>
              <p className="mt-1 text-xs text-[var(--color-ink-muted)]">
                {d.hint}
              </p>
            </div>
          ))}
        </CardContent>
      </Card>

      <Card>
        <CardHeader>
          <CardTitle>Reproduction script</CardTitle>
        </CardHeader>
        <CardContent>
          <pre className="max-h-[560px] overflow-auto rounded-md bg-[var(--color-surface-muted)] p-3 text-xs leading-relaxed">
            <code>{script ?? "Building the script…"}</code>
          </pre>
        </CardContent>
      </Card>
    </div>
  );
}
