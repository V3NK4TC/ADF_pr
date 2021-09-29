source(output(
		country as string,
		country_code as string,
		continent as string,
		population as integer,
		indicator as string,
		daily_count as integer,
		date as date,
		rate_14_day as double,
		source as string
	),
	allowSchemaDrift: false,
	validateSchema: false) ~> ECDCcasesNdeathsSource
source(output(
		country as string,
		country_code_2_digit as string,
		country_code_3_digit as string,
		continent as string,
		population as integer
	),
	allowSchemaDrift: false,
	validateSchema: false) ~> CountryCodeLookupSource
ECDCcasesNdeathsSource filter(continent == 'Asia' && not(isNull(country_code))) ~> FilterAsiaData
FilterAsiaData, CountryCodeLookupSource lookup(country_code == country_code_3_digit,
	multiple: false,
	pickup: 'any',
	broadcast: 'auto')~> LookupCountryCode
LookupCountryCode select(mapColumn(
		country = ECDCcasesNdeathsSource@country,
		country_code_2_digit,
		country_code_3_digit,
		population = ECDCcasesNdeathsSource@population,
		indicator,
		daily_count,
		reported_date = date,
		source
	),
	skipDuplicateMapInputs: false,
	skipDuplicateMapOutputs: false) ~> SelectOnlyReFields
SelectOnlyReFields pivot(groupBy(country,
		country_code_2_digit,
		country_code_3_digit,
		population,
		reported_date,
		source),
	pivotBy(indicator, ['confirmed cases', 'deaths']),
	Count = sum(daily_count),
	columnNaming: '$N_$V',
	lateral: false) ~> PivotOnIndicator
PivotOnIndicator sink(allowSchemaDrift: true,
	validateSchema: false,
	truncate: true,
	mapColumn(
		country,
		country_code_2_digit,
		country_code_3_digit,
		population,
		reported_date,
		source,
		{Count_confirmed cases},
		Count_deaths
	),
	preCommands: [],
	postCommands: []) ~> CasesNdeathsTransformed