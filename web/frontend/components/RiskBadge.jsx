import { Badge } from "@shopify/polaris";

export const RISK_BADGES = {
  out_of_stock: { status: "critical", label: "Out of stock", strong: true },
  critical: { status: "critical", label: "Critical" },
  warning: { status: "warning", label: "Warning" },
  ok: { status: "success", label: "OK" },
  no_recent_sales: { label: "No recent sales" },
};

// A risk's coloured bubble. The table shows the risk's name; the sales window puts its own sentence inside.
// The strong class gives "Out of stock" a deeper red than "Critical" (see index.html).
export function RiskBadge({ risk, children }) {
  const badge = RISK_BADGES[risk];
  return (
    <span className={badge.strong ? "badge-strong" : undefined}>
      <Badge status={badge.status}>{children ?? badge.label}</Badge>
    </span>
  );
}
