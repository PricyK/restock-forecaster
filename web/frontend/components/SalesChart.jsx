// A one-line SVG chart. Colours are Polaris CSS variables so a theme change reaches the chart too.
const PAD = { top: 10, right: 12, bottom: 24, left: 28 };

// Units sold across a range. The window shows it under the chart; the chart puts it in its screen-reader sentence.
export const rangeTotal = (range) =>
  range.points.reduce((sum, p) => sum + p.units, 0);

// Dates arrive as "YYYY-MM-DD" (midnight UTC), so format in UTC to keep the day.
function shortDate(iso) {
  return new Date(iso).toLocaleDateString(undefined, {
    month: "short",
    day: "numeric",
    timeZone: "UTC",
  });
}

// range is one of the API's ranges: { label: "7 days", points: [{ date, units }] }.
// wide: the expanded window. The drawing area grows instead of the chart scaling up, so labels keep their size.
export function SalesChart({ range, wide = false }) {
  const [WIDTH, HEIGHT] = wide ? [680, 220] : [340, 160];
  const PLOT_W = WIDTH - PAD.left - PAD.right;
  const PLOT_H = HEIGHT - PAD.top - PAD.bottom;
  const { label, points } = range;
  const unit = label.includes("week") ? "week" : "day";
  const total = rangeTotal(range);
  const top = Math.max(
    2,
    Math.ceil(Math.max(...points.map((p) => p.units)) / 2) * 2,
  ); // even, so the middle tick is whole
  const step = PLOT_W / (points.length - 1);
  const x = (i) => PAD.left + i * step;
  const y = (units) => PAD.top + PLOT_H * (1 - units / top);
  const first = shortDate(points[0].date);
  const end = new Date(points[points.length - 1].date);
  if (unit === "week") end.setUTCDate(end.getUTCDate() + 6); // a week's point is dated by its first day
  const last = shortDate(end);
  const labelled = [0, Math.floor((points.length - 1) / 2), points.length - 1];
  const coords = points.map((p, i) => `${x(i)},${y(p.units)}`);
  const lastIndex = points.length - 1; // today, or the week that includes today

  return (
    <svg
      viewBox={`0 0 ${WIDTH} ${HEIGHT}`}
      width="100%"
      role="img"
      aria-label={`Units sold per ${unit}, ${first} to ${last}: ${total} in total.`}
      style={{ fontSize: 12, fontVariantNumeric: "tabular-nums" }}
    >
      {[0, top / 2, top].map((tick) => (
        <g key={tick}>
          <line
            x1={PAD.left}
            x2={WIDTH - PAD.right}
            y1={y(tick)}
            y2={y(tick)}
            stroke="var(--p-border-subdued)"
            strokeWidth={1}
          />
          <text
            x={PAD.left - 6}
            y={y(tick)}
            textAnchor="end"
            dominantBaseline="middle"
            fill="var(--p-text-subdued)"
          >
            {tick}
          </text>
        </g>
      ))}
      {labelled.map((i, n) => (
        <text
          key={i}
          x={x(i)}
          y={HEIGHT - 6}
          textAnchor={["start", "middle", "end"][n]}
          fill="var(--p-text-subdued)"
        >
          {shortDate(points[i].date)}
        </text>
      ))}
      {/* The last point is today, or the week that includes today, so it is still counting: its segment is dashed. */}
      {[coords.slice(0, -1), coords.slice(-2)].map((segment, i) => (
        <polyline
          key={i}
          points={segment.join(" ")}
          fill="none"
          stroke="var(--p-interactive)"
          strokeWidth={2}
          strokeLinejoin="round"
          strokeLinecap="round"
          strokeDasharray={i === 1 ? "4 4" : undefined}
        />
      ))}
      {points.map((p, i) => (
        <g key={p.date}>
          {/* Dots on short ranges only; 30 dots would crowd the line. The last point always gets one. */}
          {(points.length <= 10 || i === lastIndex) && (
            <circle
              cx={x(i)}
              cy={y(p.units)}
              r={4}
              // Hollow on the last point: today is still counting (dashes alone vanish on the 30-point tab).
              fill={
                i === lastIndex ? "var(--p-surface)" : "var(--p-interactive)"
              }
              stroke="var(--p-interactive)"
              strokeWidth={i === lastIndex ? 2 : 0}
            />
          )}
          {/* A full-height strip per point, so hovering anywhere above a date shows its value. */}
          <rect
            x={x(i) - step / 2}
            y={PAD.top}
            width={step}
            height={PLOT_H}
            fill="transparent"
          >
            <title>{`${shortDate(p.date)}: ${p.units} sold${i === lastIndex ? " so far" : ""}`}</title>
          </rect>
        </g>
      ))}
    </svg>
  );
}
