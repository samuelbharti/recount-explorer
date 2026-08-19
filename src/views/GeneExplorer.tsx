import { React, useShinyInput, useShinyOutputValue } from "@/lib/shiny";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { EmptyState, Input, Label, Select } from "@/components/ui/field";
import { PlotOutput } from "@/components/ui/shiny-io";
import { cn } from "@/lib/utils";
import type { StudyState } from "@/types";

const GEOMS = [
  { value: "box", label: "Boxplot" },
  { value: "violin", label: "Violin" },
];

const MAX_SUGGESTIONS = 50;

export default function GeneExplorer() {
  const state = useShinyOutputValue<StudyState>("study_state");
  const [gene, setGene] = useShinyInput<string>("gene", "");
  const [groupBy, setGroupBy] = useShinyInput<string>("group_by", "");
  const [geom, setGeom] = useShinyInput<string>("geom", "box");
  const [term, setTerm] = React.useState("");

  // A study carries around 60,000 genes. Filtering that list in the browser is
  // quick, but rendering 60,000 options is not, so the list is capped.
  const genes = state?.loaded ? state.genes : [];
  const matches = React.useMemo(() => {
    if (!term) {
      return genes.slice(0, MAX_SUGGESTIONS);
    }
    const needle = term.toLowerCase();
    return genes
      .filter((g) => g.label.toLowerCase().includes(needle))
      .slice(0, MAX_SUGGESTIONS);
  }, [genes, term]);

  if (!state?.loaded) {
    return <EmptyState message="Load a study from the Browse view first." />;
  }

  return (
    <div className="grid gap-4 lg:grid-cols-[280px_1fr]">
      <Card className="h-fit">
        <CardHeader>
          <CardTitle>Gene</CardTitle>
        </CardHeader>
        <CardContent className="space-y-4">
          <div>
            <Label>Search</Label>
            <Input
              placeholder="Gene symbol or id"
              value={term}
              onChange={(e) => setTerm(e.target.value)}
            />
            <div className="mt-2 max-h-60 overflow-y-auto rounded-md border border-[var(--color-border-subtle)]">
              {matches.map((g) => (
                <button
                  key={g.id}
                  onClick={() => setGene(g.id)}
                  className={cn(
                    "block w-full truncate px-2 py-1 text-left text-xs",
                    gene === g.id
                      ? "bg-[var(--color-accent-soft)] text-[var(--color-accent)]"
                      : "hover:bg-[var(--color-surface-muted)]",
                  )}
                >
                  {g.label}
                </button>
              ))}
              {matches.length === 0 && (
                <p className="px-2 py-3 text-center text-xs text-[var(--color-ink-muted)]">
                  No gene matches.
                </p>
              )}
            </div>
          </div>

          <div>
            <Label>Group by</Label>
            <Select value={groupBy} onChange={(e) => setGroupBy(e.target.value)}>
              <option value="">No grouping</option>
              {state.groups.map((g) => (
                <option key={g} value={g}>
                  {g}
                </option>
              ))}
            </Select>
          </div>

          <div>
            <Label>Plot</Label>
            <div className="flex gap-1.5">
              {GEOMS.map((g) => (
                <button
                  key={g.value}
                  onClick={() => setGeom(g.value)}
                  className={cn(
                    "flex-1 rounded-md border px-2 py-1 text-xs",
                    geom === g.value
                      ? "border-[var(--color-accent)] bg-[var(--color-accent-soft)] text-[var(--color-accent)]"
                      : "border-[var(--color-border-subtle)]",
                  )}
                >
                  {g.label}
                </button>
              ))}
            </div>
          </div>
        </CardContent>
      </Card>

      <Card>
        <CardHeader>
          <CardTitle>Expression, log2 CPM</CardTitle>
        </CardHeader>
        <CardContent>
          <PlotOutput id="gene_plot" height={520} />
        </CardContent>
      </Card>
    </div>
  );
}
