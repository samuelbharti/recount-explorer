import { React, useShinyInput, useShinyOutputValue } from "@/lib/shiny";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { EmptyState, Label, Select } from "@/components/ui/field";
import { PlotOutput } from "@/components/ui/shiny-io";
import { formatCount } from "@/lib/utils";
import type { StudyState } from "@/types";

export default function PcaExplorer() {
  const state = useShinyOutputValue<StudyState>("study_state");
  const [nGenes, setNGenes] = useShinyInput<number>("n_genes", 500);
  const [colorBy, setColorBy] = useShinyInput<string>("color_by", "");
  const [draft, setDraft] = React.useState(500);

  React.useEffect(() => {
    setDraft(nGenes);
  }, [nGenes]);

  if (!state?.loaded) {
    return <EmptyState message="Load a study from the Browse view first." />;
  }

  // The slider commits on release rather than on every step. A PCA over 2,000
  // genes is not something to run sixty times during one drag.
  const commit = () => setNGenes(draft);

  return (
    <div className="grid gap-4 lg:grid-cols-[280px_1fr]">
      <Card className="h-fit">
        <CardHeader>
          <CardTitle>Settings</CardTitle>
        </CardHeader>
        <CardContent className="space-y-4">
          <div>
            <Label>Top variable genes: {formatCount(draft)}</Label>
            <input
              type="range"
              min={100}
              max={2000}
              step={100}
              value={draft}
              className="w-full accent-[var(--color-accent)]"
              onChange={(e) => setDraft(Number(e.target.value))}
              onMouseUp={commit}
              onTouchEnd={commit}
              onKeyUp={commit}
            />
          </div>
          <div>
            <Label>Color by</Label>
            <Select value={colorBy} onChange={(e) => setColorBy(e.target.value)}>
              <option value="">No coloring</option>
              {state.groups.map((g) => (
                <option key={g} value={g}>
                  {g}
                </option>
              ))}
            </Select>
          </div>
        </CardContent>
      </Card>

      <div className="grid gap-4 xl:grid-cols-[2fr_1fr]">
        <Card>
          <CardHeader>
            <CardTitle>PC1 against PC2</CardTitle>
          </CardHeader>
          <CardContent>
            <PlotOutput id="pca_plot" height={480} />
          </CardContent>
        </Card>
        <Card>
          <CardHeader>
            <CardTitle>Variance explained</CardTitle>
          </CardHeader>
          <CardContent>
            <PlotOutput id="scree_plot" height={480} />
          </CardContent>
        </Card>
      </div>
    </div>
  );
}
