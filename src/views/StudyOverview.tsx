import { React, useShinyOutputValue } from "@/lib/shiny";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { EmptyState } from "@/components/ui/field";
import { PlotOutput } from "@/components/ui/shiny-io";
import { formatCount } from "@/lib/utils";
import type { MetadataTable, StudyState } from "@/types";

function Stat({ label, value }: { label: string; value: string }) {
  return (
    <Card>
      <CardContent className="pt-4">
        <p className="text-xs font-medium uppercase tracking-wide text-[var(--color-ink-muted)]">
          {label}
        </p>
        <p className="mt-1 text-2xl font-semibold tabular-nums">{value}</p>
      </CardContent>
    </Card>
  );
}

export default function StudyOverview() {
  const state = useShinyOutputValue<StudyState>("study_state");
  const meta = useShinyOutputValue<MetadataTable>("metadata_table");
  const columns = meta?.columns ?? [];

  if (!state?.loaded) {
    return <EmptyState message="Load a study from the Browse view first." />;
  }

  return (
    <div className="space-y-4">
      <div className="grid gap-3 sm:grid-cols-2 lg:grid-cols-4">
        <Stat label="Study" value={state.project} />
        <Stat label="Samples" value={formatCount(state.n_samples)} />
        <Stat label="Genes" value={formatCount(state.n_genes)} />
        <Stat label="Source" value={state.source.toUpperCase()} />
      </div>

      <div className="grid gap-4 lg:grid-cols-2">
        <Card>
          <CardHeader>
            <CardTitle>Quality control</CardTitle>
          </CardHeader>
          <CardContent>
            <PlotOutput id="qc_plot" height={380} />
          </CardContent>
        </Card>

        <Card>
          <CardHeader>
            <CardTitle>
              {meta?.truncated
                ? `Sample metadata, first 200 of ${formatCount(meta.n_rows)}`
                : "Sample metadata"}
            </CardTitle>
          </CardHeader>
          <CardContent>
            <div className="max-h-[380px] overflow-auto">
              <table className="w-full border-collapse text-xs">
                <thead className="sticky top-0 bg-[var(--color-surface)]">
                  <tr className="border-b border-[var(--color-border-subtle)] text-left">
                    {columns.map((c) => (
                      <th
                        key={c}
                        className="whitespace-nowrap px-2 py-1.5 font-semibold"
                      >
                        {c}
                      </th>
                    ))}
                  </tr>
                </thead>
                <tbody>
                  {(meta?.rows ?? []).map((row, i) => (
                    <tr
                      key={i}
                      className="border-b border-[var(--color-border-subtle)]"
                    >
                      {columns.map((c) => (
                        <td key={c} className="whitespace-nowrap px-2 py-1">
                          {String(row[c] ?? "")}
                        </td>
                      ))}
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          </CardContent>
        </Card>
      </div>
    </div>
  );
}
