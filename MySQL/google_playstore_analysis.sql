USE google;

-- ********** Essential Tools **********
-- Creating function to get the recent year from the dataset
DELIMITER $$
CREATE FUNCTION recentYear()
RETURNS INT
DETERMINISTIC
BEGIN
	DECLARE result INT;
    SELECT MAX(YEAR(last_updated)) INTO result FROM playstore_data;
    RETURN result;
END $$
DELIMITER ;

-- Creating views to store the popular categories for later use
DROP VIEW IF EXISTS top_categories;
CREATE VIEW popular_categories AS
	SELECT
		category,
		COUNT(*) AS number_of_app,
        ROUND((COUNT(*) / (SELECT COUNT(*) FROM playstore_data)) * 100, 2) AS percentage
	FROM playstore_data
	GROUP BY category
	HAVING number_of_app >= 250
	ORDER BY number_of_app DESC;



/*
	Que-1:	Highlight the popular categories that incorporates atleast 250 application, 
			along with their contribution (%) in overall datasets.
*/    
SELECT
	*
FROM popular_categories;



/*
	Que-2:	List the top-5 application from popular categories based on the highest rating and reviews.
*/
WITH top_app AS (
		SELECT
			app,
			category,
			ROUND(AVG(rating), 1) AS rating,
			ROUND(AVG(CAST(reviews AS UNSIGNED))) AS reviews
		FROM playstore_data
		GROUP BY app, category
        HAVING reviews > 85000
	)

SELECT
	app,
    category,
    rating,
    reviews
FROM (
	SELECT
		*,
		ROW_NUMBER() OVER(PARTITION BY category ORDER BY rating DESC, reviews DESC) as rn
	FROM top_app
	WHERE category IN (SELECT category FROM popular_categories)
    )x
WHERE rn <= 5;



/*
	Que-3:	Highlight the top 3 categories which generates higher revenue.
*/
SELECT
	category,
    ROUND(SUM(revenue), 2) AS revenue
FROM (
		SELECT
			*,
			(installs * REPLACE(price, "$", "")) AS revenue
		FROM playstore_data
		WHERE type = "Paid"
	) x
GROUP BY category
ORDER BY revenue DESC
LIMIT 3;



/*
	Que-4:	List those category which has maximum growth in application building from the recet three years. 
*/
WITH CTE AS (
	SELECT
		category,
		COUNT(DISTINCT YEAR(last_updated)) AS year
	FROM playstore_data
	WHERE YEAR(last_updated) > recentYear() - 3
	GROUP BY category
	HAVING year = 3
	),

	 prev_year_app_made AS (
		SELECT
			*,
			LAG(app_made, 1) OVER(PARTITION BY category ORDER BY year) as prev_app_made
		FROM (
				SELECT
					category,
					YEAR(last_updated) AS year,
					COUNT(*) AS app_made
				FROM playstore_data
				WHERE YEAR(last_updated) > recentYear() - 3 AND category IN (SELECT category FROM CTE)
				GROUP BY category, year
				)x
		)

SELECT	
	category,
	MAX(ROUND(((app_made - prev_app_made) / prev_app_made) * 100, 2)) AS growth
FROM prev_year_app_made
GROUP BY category
ORDER BY growth DESC
LIMIT 5;



/*
	Que-5:	Find out which category is best for developer to design free or paid application.
*/
WITH free_paid_decision AS (
		SELECT
			category,
			MAX(CASE WHEN type = "Free" THEN rating END) AS free_rating,
			MAX(CASE WHEN type = "Paid" THEN rating END) AS paid_rating
		FROM (
				SELECT
					category,
					type,
					ROUND(AVG(rating), 2) AS rating
				FROM playstore_data
				GROUP BY category, type
			) a
		GROUP BY category
		HAVING paid_rating IS NOT NULL
	)

SELECT
	*,
    IF (free_rating < paid_rating, "Make Paid App", "Make Free App") AS decision
FROM free_paid_decision;