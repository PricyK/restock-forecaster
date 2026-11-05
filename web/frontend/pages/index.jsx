import {
  Badge,
  Banner,
  Card,
  DataTable,
  EmptyState,
  Layout,
  Page,
  SkeletonBodyText,
  Text,
} from "@shopify/polaris";
import { useQuery } from "react-query";

import { notFoundImage } from "../assets";

const RISK_BADGES = {
  out_of_stock: { status: "critical", label: "Out of stock" },
  critical: { status: "critical", label: "Critical" },
  warning: { status: "warning", label: "Warning" },
  ok: { status: "success", label: "OK" },
  no_recent_sales: { label: "No recent sales" },
};

const SUMMARY = [
  ["critical", "critical"],
  ["warning", "warning"],
  ["out_of_stock", "out of stock"],
];

const FALLBACK_ERROR = "Couldn't load data from Shopify. Try again.";

// App Bridge adds the session token to fetch() calls, so the Rails endpoint knows which store is asking.
async function fetchForecast() {
  const response = await fetch("/api/forecast");
  const body = await response.json().catch(() => ({}));
  if (!response.ok) throw new Error(body.error || FALLBACK_ERROR);
  return body;
}

// Dates arrive as "YYYY-MM-DD". Formatting in UTC stops the browser's time zone from shifting the day.
function formatDate(iso) {
  if (!iso) return "—";
  return new Date(iso).toLocaleDateString(undefined, {
    month: "short",
    day: "numeric",
    year: "numeric",
    timeZone: "UTC",
  });
}

function summarize(rows) {
  const parts = SUMMARY.map(([risk, label]) => [
    rows.filter((row) => row.risk === risk).length,
    label,
  ])
    .filter(([count]) => count > 0)
    .map(([count, label]) => `${count} ${label}`);
  return parts.length > 0 ? parts.join(" · ") : "Nothing at risk";
}

function ForecastTable({ rows }) {
  if (rows.length === 0) {
    return (
      <Card sectioned>
        <EmptyState heading="No products yet" image={notFoundImage}>
          <p>
            Add products that track inventory to see when they will run out.
          </p>
        </EmptyState>
      </Card>
    );
  }

  return (
    <Card>
      <Card.Section>
        <Text as="p" variant="headingMd">
          {summarize(rows)}
        </Text>
      </Card.Section>
      <DataTable
        columnContentTypes={[
          "text",
          "text",
          "text",
          "numeric",
          "numeric",
          "numeric",
          "text",
          "text",
        ]}
        headings={[
          "Product",
          "Variant",
          "SKU",
          "Stock",
          "Sold/day",
          "Days left",
          "Runs out",
          "Risk",
        ]}
        rows={rows.map((row) => {
          const badge = RISK_BADGES[row.risk];
          return [
            row.product_title,
            row.variant_title ?? "",
            row.sku ?? "",
            row.inventory,
            row.daily_rate,
            row.days_left ?? "—",
            formatDate(row.run_out_date),
            <Badge key={row.id} status={badge.status}>
              {badge.label}
            </Badge>,
          ];
        })}
      />
    </Card>
  );
}

export default function HomePage() {
  const { data, error, isLoading, isFetching, refetch } = useQuery({
    queryKey: ["forecast"],
    queryFn: fetchForecast,
    refetchOnWindowFocus: false,
    retry: false,
  });

  return (
    <Page
      title="Restock Forecaster"
      primaryAction={{
        content: "Refresh",
        onAction: () => refetch(),
        loading: isFetching,
        disabled: isLoading,
      }}
    >
      <Layout>
        {error && (
          <Layout.Section>
            <Banner
              status="critical"
              title="Couldn't load the forecast"
              action={{
                content: "Retry",
                onAction: () => refetch(),
                loading: isFetching,
              }}
            >
              <p>{error.message}</p>
            </Banner>
          </Layout.Section>
        )}
        <Layout.Section>
          {isLoading && (
            <Card sectioned>
              <SkeletonBodyText lines={6} />
            </Card>
          )}
          {data && <ForecastTable rows={data.rows} />}
        </Layout.Section>
      </Layout>
    </Page>
  );
}
