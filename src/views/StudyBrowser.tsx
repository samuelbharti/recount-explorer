import { Search, Download, ExternalLink, Loader2 } from "lucide-react";

import {
  React,
  useShinyInput,
  useShinyOutputValue,
  useShinyOutputStatus,
} from "@/lib/shiny";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Badge, Input, Label, Select } from "@/components/ui/field";
import { cn, formatCount } from "@/lib/utils";
import { TableSkeleton } from "@/components/ui/skeleton";
import type {
  CatalogFacets,
  CatalogPage,
  CatalogStatus,
  LoadStatus,
  StudyDetails,
} from "@/types";

const PAGE_SIZES = [10, 25, 50, 100];

/** Debounce the search box so R greps 19,000 rows once per pause, not per key. */
function useDebounced<T>(value: T, ms: number): T {
  const [held, setHeld] = React.useState(value);
  React.useEffect(() => {
    const t = window.setTimeout(() => setHeld(value), ms);
    return () => window.clearTimeout(t);
  }, [value, ms]);
  return held;
}

export default function StudyBrowser() {
  const status = useShinyOutputValue<CatalogStatus>("catalog_status");
  const facets = useShinyOutputValue<CatalogFacets>("catalog_facets");
  const page = useShinyOutputValue<CatalogPage>("catalog_page");
  const details = useShinyOutputValue<StudyDetails>("study_details");
  const loadStatus = useShinyOutputValue<LoadStatus>("load_status");
  const pageStatus = useShinyOutputStatus("catalog_page");

  const [typed, setTyped] = React.useState("");
  const debounced = useDebounced(typed, 300);
  const [, setQuery] = useShinyInput<string>("q", "");
  const [organisms, setOrganisms] = useShinyInput<string[]>("organisms", []);
  const [sources, setSources] = useShinyInput<string[]>("sources", []);
  const [minSamples, setMinSamples] = useShinyInput<number | null>(
    "min_samples",
    null,
  );
  const [maxSamples, setMaxSamples] = useShinyInput<number | null>(
    "max_samples",
    null,
  );
  const [current, setPage] = useShinyInput<number>("page", 1);
  const [pageSize, setPageSize] = useShinyInput<number>("page_size", 25);
  const [sortBy, setSortBy] = useShinyInput<string>("sort_by", "n_samples");
  const [sortDir, setSortDir] = useShinyInput<string>("sort_dir", "desc");
  const [selectedUid, setSelectedUid] = useShinyInput<string>(
    "selected_uid",
    "",
  );
  const [, triggerLoad] = useShinyInput<number>("load_study", 0, {
    priority: "event",
  });

  React.useEffect(() => {
    setQuery(debounced);
    setPage(1);
  }, [debounced]);

  const loading = loadStatus?.status === "running";

  function toggle(list: string[], value: string, set: (v: string[]) => void) {
    set(list.includes(value) ? list.filter((v) => v !== value) : [...list, value]);
    setPage(1);
  }

  function sortOn(column: string) {
    if (sortBy === column) {
      setSortDir(sortDir === "desc" ? "asc" : "desc");
    } else {
      setSortBy(column);
      setSortDir(column === "n_samples" ? "desc" : "asc");
    }
    setPage(1);
  }

  const headers: Array<{ key: string; label: string; sortable: boolean }> = [
    { key: "project", label: "Study", sortable: true },
    { key: "organism", label: "Organism", sortable: true },
    { key: "file_source", label: "Source", sortable: true },
    { key: "n_samples", label: "Samples", sortable: true },
    { key: "study_title", label: "Title", sortable: true },
  ];

  return (
    <div className="grid gap-4 lg:grid-cols-[260px_1fr]">
      <aside className="space-y-4">
        <Card>
          <CardHeader>
            <CardTitle>Filters</CardTitle>
          </CardHeader>
          <CardContent className="space-y-4">
            <div>
              <Label>Organism</Label>
              <div className="flex flex-wrap gap-1.5">
                {(facets?.organisms ?? []).map((o) => (
                  <button
                    key={o}
                    onClick={() => toggle(organisms, o, setOrganisms)}
                    className={cn(
                      "rounded-full border px-2.5 py-0.5 text-xs capitalize",
                      organisms.includes(o)
                        ? "border-[var(--color-accent)] bg-[var(--color-accent-soft)] text-[var(--color-accent)]"
                        : "border-[var(--color-border-subtle)] bg-[var(--color-surface)]",
                    )}
                  >
                    {o}
                  </button>
                ))}
              </div>
            </div>

            <div>
              <Label>Data source</Label>
              <div className="flex flex-wrap gap-1.5">
                {(facets?.sources ?? []).map((s) => (
                  <button
                    key={s}
                    onClick={() => toggle(sources, s, setSources)}
                    className={cn(
                      "rounded-full border px-2.5 py-0.5 text-xs",
                      sources.includes(s)
                        ? "border-[var(--color-accent)] bg-[var(--color-accent-soft)] text-[var(--color-accent)]"
                        : "border-[var(--color-border-subtle)] bg-[var(--color-surface)]",
                    )}
                  >
                    {s}
                  </button>
                ))}
              </div>
            </div>

            <div>
              <Label>Samples</Label>
              <div className="flex items-center gap-2">
                <Input
                  type="number"
                  min={0}
                  placeholder="min"
                  value={minSamples ?? ""}
                  onChange={(e) => {
                    const v = e.target.value;
                    setMinSamples(v === "" ? null : Number(v));
                    setPage(1);
                  }}
                />
                <span className="text-xs text-[var(--color-ink-muted)]">to</span>
                <Input
                  type="number"
                  min={0}
                  placeholder="max"
                  value={maxSamples ?? ""}
                  onChange={(e) => {
                    const v = e.target.value;
                    setMaxSamples(v === "" ? null : Number(v));
                    setPage(1);
                  }}
                />
              </div>
            </div>

            {(organisms.length > 0 ||
              sources.length > 0 ||
              minSamples !== null ||
              maxSamples !== null ||
              typed !== "") && (
              <Button
                variant="ghost"
                size="sm"
                className="w-full"
                onClick={() => {
                  setOrganisms([]);
                  setSources([]);
                  setMinSamples(null);
                  setMaxSamples(null);
                  setTyped("");
                  setPage(1);
                }}
              >
                Clear all filters
              </Button>
            )}
          </CardContent>
        </Card>
      </aside>

      <div className="space-y-4">
        <Card>
          <CardContent className="pt-4">
            <div className="relative">
              <Search className="pointer-events-none absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-[var(--color-ink-muted)]" />
              <Input
                className="pl-9"
                disabled={!facets}
                placeholder={
                  facets
                    ? `Search ${formatCount(facets.total)} studies by accession, title or abstract`
                    : status?.state === "missing"
                      ? "No catalog snapshot"
                      : "Reading the study catalog…"
                }
                value={typed}
                onChange={(e) => setTyped(e.target.value)}
              />
            </div>
            <p className="mt-2 text-xs text-[var(--color-ink-muted)]">
              {page
                ? page.matched === page.total
                  ? `Showing all ${formatCount(page.total)} studies.`
                  : `${formatCount(page.matched)} of ${formatCount(page.total)} studies match.`
                : (status?.message ?? "Connecting to the server…")}
            </p>
          </CardContent>
        </Card>

        <Card>
          <div
            className={cn(
              "overflow-x-auto transition-opacity",
              pageStatus === "recalculating" && "opacity-60",
            )}
          >
            <table className="w-full border-collapse text-sm">
              <thead>
                <tr className="border-b border-[var(--color-border-subtle)] text-left">
                  {headers.map((h) => (
                    <th
                      key={h.key}
                      className="px-3 py-2 text-xs font-semibold uppercase tracking-wide text-[var(--color-ink-muted)]"
                    >
                      <button
                        className="inline-flex items-center gap-1 hover:text-[var(--color-ink)]"
                        onClick={() => sortOn(h.key)}
                      >
                        {h.label}
                        {sortBy === h.key && (
                          <span aria-hidden>{sortDir === "desc" ? "▾" : "▴"}</span>
                        )}
                      </button>
                    </th>
                  ))}
                </tr>
              </thead>
              <tbody>
                {(page?.rows ?? []).map((row) => (
                  <tr
                    key={row.uid}
                    onClick={() => setSelectedUid(row.uid)}
                    className={cn(
                      "cursor-pointer border-b border-[var(--color-border-subtle)]",
                      selectedUid === row.uid
                        ? "bg-[var(--color-accent-soft)]"
                        : "hover:bg-[var(--color-surface-muted)]",
                    )}
                  >
                    <td className="px-3 py-2 font-mono text-xs">{row.project}</td>
                    <td className="px-3 py-2 capitalize">{row.organism}</td>
                    <td className="px-3 py-2">{row.file_source}</td>
                    <td className="px-3 py-2 tabular-nums">
                      {formatCount(row.n_samples)}
                    </td>
                    <td className="px-3 py-2">{row.study_title}</td>
                  </tr>
                ))}
                {page && page.rows.length === 0 && (
                  <tr>
                    <td
                      colSpan={headers.length}
                      className="px-3 py-10 text-center text-[var(--color-ink-muted)]"
                    >
                      {status?.state === "missing"
                        ? status.message
                        : "No study matches that search."}
                    </td>
                  </tr>
                )}
              </tbody>
            </table>
            {!page && status?.state !== "missing" && <TableSkeleton />}
          </div>

          <div className="flex flex-wrap items-center justify-between gap-2 border-t border-[var(--color-border-subtle)] px-3 py-2 text-xs">
            <span className="text-[var(--color-ink-muted)]">
              {page ? `${formatCount(page.from)}–${formatCount(page.to)} of ${formatCount(page.matched)}` : ""}
            </span>
            <div className="flex items-center gap-2">
              <Select
                className="h-7 w-auto py-0 text-xs"
                value={pageSize}
                onChange={(e) => {
                  setPageSize(Number(e.target.value));
                  setPage(1);
                }}
              >
                {PAGE_SIZES.map((n) => (
                  <option key={n} value={n}>
                    {n} per page
                  </option>
                ))}
              </Select>
              <Button
                size="sm"
                disabled={!page || page.page <= 1}
                onClick={() => setPage(Math.max(1, current - 1))}
              >
                Previous
              </Button>
              <span className="tabular-nums text-[var(--color-ink-muted)]">
                {page ? `${page.page} / ${page.pages}` : ""}
              </span>
              <Button
                size="sm"
                disabled={!page || page.page >= page.pages}
                onClick={() => setPage(current + 1)}
              >
                Next
              </Button>
            </div>
          </div>
        </Card>

        <Card>
          <CardHeader>
            <CardTitle>Selected study</CardTitle>
          </CardHeader>
          <CardContent>
            {!details ? (
              <p className="text-sm text-[var(--color-ink-muted)]">
                Select a study in the table to read its abstract.
              </p>
            ) : (
              <div className="space-y-3">
                <h3 className="text-base font-semibold">{details.title}</h3>
                <div className="flex flex-wrap gap-1.5">
                  <Badge className="font-mono">{details.project}</Badge>
                  <Badge className="capitalize">{details.organism}</Badge>
                  <Badge>{details.source.toUpperCase()}</Badge>
                  <Badge>{formatCount(details.n_samples)} samples</Badge>
                </div>
                {details.large && (
                  <p className="rounded-md border-l-4 border-[var(--color-warn)] bg-[var(--color-warn-soft)] px-3 py-2 text-xs text-[var(--color-warn)]">
                    This study is large. It takes a long time to load and it
                    needs a lot of memory.
                  </p>
                )}
                <p className="max-h-52 overflow-y-auto rounded-md bg-[var(--color-surface-muted)] p-3 text-sm leading-relaxed">
                  {details.abstract || "recount3 has no abstract for this study."}
                </p>
                <div className="flex flex-wrap items-center gap-3">
                  <Button
                    variant="primary"
                    onClick={() => triggerLoad(Date.now())}
                    disabled={loading}
                  >
                    {loading ? (
                      <>
                        <Loader2 className="h-4 w-4 animate-spin" />
                        Loading {loadStatus?.project}…
                      </>
                    ) : (
                      <>
                        <Download className="h-4 w-4" />
                        Load this study
                      </>
                    )}
                  </Button>
                  {details.links.map((l) => (
                    <a
                      key={l.href}
                      href={l.href}
                      target="_blank"
                      rel="noopener"
                      className="inline-flex items-center gap-1 text-xs text-[var(--color-accent)] hover:underline"
                    >
                      {l.label}
                      <ExternalLink className="h-3 w-3" />
                    </a>
                  ))}
                </div>
              </div>
            )}
          </CardContent>
        </Card>
      </div>
    </div>
  );
}
