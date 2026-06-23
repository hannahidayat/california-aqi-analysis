library(tidyverse)
library(sf)

#read data
## ---- load-california
aqi <- read.csv("data/annual_aqi_by_county_2025.csv")

#filter for california
California_aqi <- dplyr::filter(aqi, State =="California")
knitr::kable(California_aqi)


## ---- worst-counties
# find worst counties for air quality (top 3)
aqi <- read.csv("data/annual_aqi_by_county_2025.csv")
California_aqi <- dplyr::filter(aqi, State =="California")

top_3_counties_worst <- California_aqi %>%
  mutate(
    percent_days_not_good = ((Days.with.AQI - Good.Days) / Days.with.AQI) * 100,
    rank_severity = rank(Median.AQI),
    rank_duration = rank(percent_days_not_good),
    composite_score = (rank_severity + rank_duration) / 2
  ) %>%
  select(County, Median.AQI, Good.Days, Days.with.AQI, percent_days_not_good, composite_score) %>%
  arrange(desc(composite_score)) %>%
  head(3)

knitr::kable(top_3_counties_worst, align = "lccccc")


## ---- chem-profile
# find out why these counties are worst through chemical profile 
top_worst <- top_3_counties_worst$County

chemical_ratio <- California_aqi %>%
  filter(County %in% top_worst) %>%
  mutate(
    NO2 = (Days.NO2 / Days.with.AQI) * 100,
    PM2.5 = (Days.PM2.5 / Days.with.AQI) * 100,
    Ozone = (Days.Ozone / Days.with.AQI) * 100 
  ) %>%
  select(County, NO2, PM2.5, Ozone) %>%
  arrange(desc(Ozone))

# create a chemical profile visual 
chart_data_long <- chemical_ratio %>%
  pivot_longer(
    cols = c(Ozone, PM2.5, NO2),
    names_to = "Pollutant",
    values_to = "Percentage"
  )

ggplot(data = chart_data_long, aes(x = Pollutant, y = County, fill = Percentage)) +
  
  geom_tile(color = "white", linewidth = 0.5) +
  
  geom_text(aes(label = paste0(round(Percentage, 1), "%")), 
            color = "black", fontface = "bold", size = 4) +
  
  scale_fill_gradient(low = "#e8f5e9", high = "#FF474C", name = "Frequency") +
  
  theme_minimal() +
  
  theme(
    panel.grid = element_blank(),
    axis.text = element_text(size = 11, face = "bold"),
    plot.title = element_text(face = "bold", size = 14),
    legend.position = "none"
  ) +
  
  labs(
    x = "Pollutant",
    y = "Hotspot County",
    title = "California Air Quality Profile Comparison",
    subtitle = "Frequency concentration mapping (2025) - US EPA AirData"
  )


## ---- sensitive-groups
# compare unhealthy days for sensitive groups of 3 counties vs rest of california 
California_aqi <- California_aqi %>%
  mutate(is_top_3 = if_else(County %in% top_worst, "Top 3 Hotspots", "Rest of California"))

risk_comparison <- California_aqi %>%
  group_by(is_top_3) %>%
  summarize(avg_days_usg = mean(Unhealthy.for.Sensitive.Groups.Days, na.rm = TRUE))

avg_top3 <- risk_comparison$avg_days_usg[risk_comparison$is_top_3 == "Top 3 Hotspots"]

avg_rest <- risk_comparison$avg_days_usg[risk_comparison$is_top_3 == "Rest of California"]

multiplier <- avg_top3 / avg_rest

print(paste("The top 3 hotspot counties experience", round(multiplier, 1), "times more toxic days for sensitive groups than the rest of California."))


## ---- sensitive-viz
# visual comparison of days for USG
simple_chart_data <- California_aqi %>%
  filter(!is.na(Unhealthy.for.Sensitive.Groups.Days)) %>%
  filter(Unhealthy.for.Sensitive.Groups.Days > 0) %>%
  mutate(is_hotspot = if_else(County %in% top_worst, "Hotspot", "Normal"))

ggplot(data = simple_chart_data, 
       aes(x = reorder(County, Unhealthy.for.Sensitive.Groups.Days), 
           y = Unhealthy.for.Sensitive.Groups.Days, 
           fill = is_hotspot)) + 
  
  geom_col(width = 0.8) +
  
  scale_fill_manual(values = c("Hotspot" = "#FF474C", "Normal" = "#778899")) +
  
  coord_flip() +
  
  theme_minimal() +
  theme(
    legend.position = "none",                   
    panel.grid.minor = element_blank(),         
    panel.grid.major.y = element_blank(),       
    axis.text.y = element_text(size = 8), 
    plot.title = element_text(face = "bold")
  ) +
  
  labs(
    x = "County",
    y = "Number of Unhealthy Days (Sensitive Groups)",
    title = "Distribution of California Air Quality Hazards",
    subtitle = "Highlighting the top 3 high-burden counties - US EPA AirData"
  )
