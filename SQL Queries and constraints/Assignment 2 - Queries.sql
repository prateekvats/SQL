/*
Prateek Vats

Hi. Majority of my assignment has been done via Common Table Expressions(CTE). That was one major advantage of doing this via SQL SERVER.
In my experience, using CTE's results in clean queries and helps you write down your thought process for the queries much clearly.
*/



/*Query 1

LA Dodgers - List the first name and last name of every player that has played at any 
time in their career for the Los Angeles Dodgers. List each player only once.

*/

SELECT DISTINCT m.nameFirst,m.nameLast 

FROM baseball.dbo.appearances a
INNER JOIN baseball.dbo.master m
ON a.masterID=m.masterID

where a.teamID = (select DISTINCT teamID from baseball.dbo.teams where name='Los Angeles Dodgers')
order by m.nameLast


/*Query 2

LA Dodgers Only - List the first name and last name of every player that has played only for the Los Angeles Dodgers 
(i.e., they did not play for any other team including the Brooklyn Dodgers, 
note that the Brooklyn Dodgers became the Los Angeles Dodgers in the 1950s). List each player only once. 

*/

SELECT nameFirst,nameLast 
from   baseball.dbo.master
where  masterID 
 IN     (

		SELECT a.masterID 
		FROM baseball.dbo.appearances a
		WHERE a.masterID NOT IN(

				SELECT   DISTINCT a.masterID
				FROM     baseball.dbo.appearances a
				WHERE    a.teamID != (select DISTINCT teamID from baseball.dbo.teams where name= 'Los Angeles Dodgers')
		)
)
ORDER BY nameLast


/*Query 3

Expos Pitchers - List the first name and last name of every player that has pitched for the team named the "Montreal Expos". 
List each player only once.


*/

SELECT nameFirst,nameLast
from   baseball.dbo.master
where  masterID IN(
		SELECT DISTINCT p.masterID
		FROM baseball.dbo.pitching p
		WHERE p.teamID =(
						select DISTINCT teamID from baseball.dbo.teams where name= 'Montreal Expos'
						)
				  )
ORDER BY nameLast

/*Query 4

Error Kings - List the name of the team, year, 
and number of errors (the number is the "E" column in the "teams" table)
 for every team that has had 160 or more errors in a season. 

*/

SELECT t.name,t.yearID,t.E 
FROM baseball.dbo.teams t
where t.E >=160
ORDER BY t.yearID


/*Query 5

USU batters - List the first name, last name, year played, 
and batting average (h/ab) of every player from the school named "Utah State University"

*/

SELECT Round(re.BattingAverage,4) "Average",re.H "Hits" ,re.AB "At Bats",m.nameFirst "First Name",m.nameLast "Last Name",re.yearID "Year"
FROM baseball.dbo.master m
INNER JOIN
				(
				SELECT CAST(b.H AS FLOAT)/NULLIF(CAST(b.AB AS FLOAT),CAST(0.0 AS FLOAT)) BattingAverage,b.H,b.AB,b.yearID,b.masterID
				FROM baseball.dbo.batting b
				WHERE b.masterID IN (
						SELECT masterID
						FROM baseball.dbo.schoolsPlayers 
						WHERE schoolID = (
											SELECT schoolID 
											FROM baseball.dbo.schools WHERE
											schoolName='Utah State University'
										)
						)
				AND b.H IS NOT NULL
				) re
ON
re.masterID=m.masterID
ORDER BY re.yearID


/* Query 6 

Yankee Run Kings - List the name, year, and number of home runs hit for each New York Yankee batter, 
but only if they hit the most home runs for any player in that season.


*/

WITH MAX_RUNS 
AS
(
	SELECT   yearID,max(HR) MaxHomeRuns
	FROM     baseball.dbo.batting 
	GROUP BY yearID
),

Player_WithMAXHR 
AS
(
	SELECT      B.masterID, B.teamID, B.yearID, B.HR
	FROM        baseball.dbo.batting  B
	INNER JOIN  MAX_RUNS              MR
	ON	        B.yearID = MR.yearID
	AND         B.HR     = MR.MaxHomeRuns
	WHERE       B.teamID IN (Select distinct teamID from baseball.dbo.teams where name = 'NEW YORK YANKEES')
)

SELECT     M.NameFirst, M.NameLast, P.yearID "Year",P.HR
FROM       Player_WithMAXHR  P
INNER JOIN baseball.dbo.master M
ON         P.masterID = M.masterID
ORDER BY   P.yearID;


/* Query 7 

Bumper Salary Teams - List the total salary for two consecutive years, team name, 
and year for every team that had a total salary which was 1.5 times as much as for the previous year.

*/

WITH TeamSalaries
AS
(
	SELECT distinct teamID,yearID,SUM(salary) salary
	FROM baseball.dbo.salaries
	GROUP BY teamID,yearID

),
TeamSalaries_TwoYears
AS
(
	SELECT t.teamID,t.yearID ThisYear,tt.yearID AS PreviousYear,t.salary AS ThisSalary,tt.salary AS PreviousSalary,(tt.salary+t.salary) AS TotalTwoSalary
	FROM TeamSalaries t
	INNER JOIN TeamSalaries tt
	ON t.teamID=tt.teamID

	WHERE (t.yearID-tt.yearID)=1 AND t.salary>=(1.5*tt.salary)
)
	SELECT distinct t.name "Team Name",t.lgID "League",s.PreviousYear "Previous Year",
	s.PreviousSalary "Previous Salary",s.ThisYear "Year",
	s.ThisSalary "Salary",FLOOR((s.ThisSalary/s.PreviousSalary*100)) "Percent Increase"
	FROM 
	TeamSalaries_TwoYears s
	INNER JOIN
	baseball.dbo.teams t
	ON
	t.teamID=s.teamID
	ORDER BY s.PreviousYear

/*Query 8

Montreal Expos Three - List the first name and last name of every player that 
has batted for the Montreal Expos in at least three consecutive years. 
List each player only once.

*/

WITH MontrealExposPlayers
AS(	

	SELECT masterID,yearID
	FROM baseball.dbo.appearances
	where teamID = (
						select DISTINCT teamID from baseball.dbo.teams where name='Montreal Expos'
					)
),
PlayersWhoPlayedConsecutively
AS(
	SELECT DISTINCT p1.yearID year1,p2.yearID Year2,p3.yearID Year3,p1.masterID masterID
	FROM MontrealExposPlayers p1
	INNER JOIN MontrealExposPlayers p2
	ON
	p1.masterID=p2.masterID
	INNER JOIN MontrealExposPlayers p3
	ON
	p2.masterID=p3.masterID
	WHERE
	p1.yearID=(p2.yearID-1) AND p2.yearID=(p3.yearID-1)
)

SELECT DISTINCT m.nameFirst "First Name",m.nameLast "Last Name" FROM
PlayersWhoPlayedConsecutively pc
INNER JOIN baseball.dbo.master m
ON
pc.masterID=m.masterID
ORDER BY m.nameLast


/*Query 9

Home Run Kings - List the first name, last name, year, and number of HRs of every player that has hit the most home runs in a single season. 
Order by the year. Note that the "batting" table has a column "HR" with the number of home runs hit by a player in that year.

*/

WITH MaxHRInASeason
AS(

	SELECT yearID,max(HR) MaxHomeRuns
	FROM baseball.dbo.batting
	GROUP BY yearID
),
MaxHRPlayers 
AS(
	SELECT p.masterID,m.yearID,m.MaxHomeRuns
	FROM baseball.dbo.batting p 
	INNER JOIN
	MaxHRInASeason m ON
	m.yearID=p.yearID AND m.MaxHomeRuns=p.HR
)
SELECT mhp.yearID "Year",m.nameFirst "First Name",m.nameLast "Last Name",mhp.MaxHomeRuns "Home Runs"
FROM MaxHRPlayers mhp
INNER JOIN baseball.dbo.master m
ON
m.masterID=mhp.masterID
ORDER BY mhp.yearID

/*Query 10

Third best home runs each year - List the first name, last name, year, 
and number of HRs of every player that hit the third most home runs for that year. Order by the year.

*/

WITH MaxHRInASeason
AS(

	SELECT yearID,max(HR) MaxHomeRuns
	FROM baseball.dbo.batting
	GROUP BY yearID
),
SecondMostHR
AS(
	SELECT b.yearID,max(b.HR) MaxHomeRuns
	FROM baseball.dbo.batting b
	INNER JOIN MaxHRInASeason m ON
	b.yearID=m.yearID AND b.HR<m.MaxHomeRuns
	GROUP BY b.yearID
	),
ThirdMostHR
AS(
	SELECT b.yearID,max(b.HR) MaxHomeRuns
	FROM baseball.dbo.batting b
	INNER JOIN SecondMostHR sm ON
	b.yearID=sm.yearID AND b.HR<sm.MaxHomeRuns
	GROUP BY b.yearID
),
ThirdHighestHR_Players
AS(
	SELECT p.masterID,p.yearID,th.MaxHomeRuns
	FROM ThirdMostHR th
	INNER JOIN baseball.dbo.batting p
	ON 
	th.yearID=p.yearID AND th.MaxHomeRuns=p.HR
)
SELECT m.nameFirst "First Name",m.nameLast "Last Name",thp.yearID "Year",thp.MaxHomeRuns "HRs"
FROM ThirdHighestHR_Players thp
INNER JOIN baseball.dbo.master m
ON
thp.masterID=m.masterID
order by thp.yearID


/* Query 11 

Triple happy team mates - List the team name, year, names of player, the number of triples hit (column "3B" in the batting table), 
in which two or more players on the same team hit 10 or more triples each.

*/
use baseball;
WITH PlayersWhoHitTriples
AS(
		SELECT masterID,yearID,teamID,"3B" Triples
		FROM
		baseball.dbo.batting 
		WHERE "3B">=10
),
SuchTeams
AS(
		SELECT teamID,yearID,count(masterID) PlayerCount
		FROM PlayersWhoHitTriples
		GROUP BY teamID,yearID
		HAVING 
		count(masterID)>=2
)
--select * from SuchTeams order by yearID
,
SuchTeamsAndPlayers
AS(
		SELECT s.teamID,s.PlayerCount,p.yearID,p.masterID,p.Triples
		FROM PlayersWhoHitTriples p
		INNER JOIN SuchTeams s ON
		p.teamID=s.teamID AND p.yearID=s.yearID
),
SuchTeamsAndPlayers_WithNames
AS(
		SELECT DISTINCT s.teamID,s.yearID,m.nameFirst,m.nameLast,s.Triples
		FROM SuchTeamsAndPlayers s
		INNER JOIN baseball.dbo.master m ON
		m.masterID=s.masterID

),
HappyTeamMates
AS(
		SELECT stp1.yearID,stp1.teamID,stp1.nameFirst "FirstName1",stp1.nameLast "LastName1", stp1.Triples "Triples1",stp2.nameFirst "FirstName2",stp2.nameLast "LastName2",stp2.Triples "Triples2"
		FROM SuchTeamsAndPlayers_WithNames stp1
		INNER JOIN SuchTeamsAndPlayers_WithNames stp2
		ON
		stp1.teamID=stp2.teamID AND stp1.yearID=stp2.yearID AND stp1.nameLast < stp2.nameLast
)
SELECT DISTINCT hmt.yearID Year,t.name,hmt.FirstName1 "First Name",hmt.LastName1 "Last Name",
				hmt.Triples1 "Triples",hmt.FirstName2 "Teammates First Name",hmt.LastName2 "Teammates Last Name",
				hmt.Triples2 "Teammates Triples" FROM HappyTeamMates hmt

INNER JOIN baseball.dbo.teams t
ON
t.teamID=hmt.teamID AND t.yearID=hmt.yearID
order by hmt.yearID

/*Query 12

Ranking the teams - Rank each team in terms of the winning percentage (wins divided by (wins + losses)) over its entire history. Consider a "team" to be a team with the same name, so if the team changes name, 
it is considered to be two different teams. Show the team name, win percentage, and the rank.

*/


WITH TeamsAccordingToWinningPercentage
AS(

		SELECT name,ROUND(CAST(SUM(W) AS FLOAT)/CAST(SUM(W)+SUM(L) AS FLOAT),4) TeamsWinningPercentage,SUM(W) Wins,SUM(L) Losses
		FROM baseball.dbo.teams
		GROUP BY name
),
TeamsAccordingToRank AS(
		SELECT count(t1.name) "Rank",t1.name
		FROM TeamsAccordingToWinningPercentage t1,TeamsAccordingToWinningPercentage t2
		WHERE
		t1.name!=t2.name AND t1.TeamsWinningPercentage<t2.TeamsWinningPercentage
		GROUP BY t1.name
)
SELECT TR.name "Team Name",TR.Rank,TWP.TeamsWinningPercentage "Win Percentage",
	   TWP.Wins "Total Wins", TWP.Losses "Total Losses"
	   FROM TeamsAccordingToRank TR
	   INNER JOIN TeamsAccordingToWinningPercentage TWP
	   ON
	   TR.name=TWP.name
	   ORDER BY TR.Rank

/*This was another way to do it by using row_number() method to order the teams by rank*/
--SELECT row_number() OVER (ORDER BY TeamsWinningPercentage DESC) AS RANK,* FROM TeamsAccordingToWinningPercentage
--ORDER BY TeamsWinningPercentage DESC



/*Query 13

Pitchers for Mangaer Casey Stengel - List the year, first name, 
and last name of each pitcher who was a on a team managed by Casey Stengel (pitched in the same season on a team managed by Casey).

*/

WITH CaseyStengelInfo
AS(

			SELECT m2.nameFirst "ManagersFirstName",m2.nameLast "ManagersLastName",m1.teamID,m1.yearID
			FROM baseball.dbo.managers m1
			INNER JOIN baseball.dbo.master m2
			ON m1.masterID=m2.masterID
			WHERE m2.nameFirst='Casey' AND m2.nameLast='Stengel'
),
PitchersWithCasey AS
(
			SELECT p.yearID,p.masterID,csi.ManagersFirstName,csi.ManagersLastName,csi.teamID
			FROM
			baseball.dbo.pitching p
			INNER JOIN CaseyStengelInfo csi
			ON
			p.teamID=csi.teamID AND p.yearID=csi.yearID
)

SELECT  t.name "Team Name",p.yearID Year,m.nameFirst "First Name",m.nameLast "Last Name",
		p.ManagersFirstName "Manager First Name",p.ManagersLastName "Manager Last Name"
FROM baseball.dbo.master m
INNER JOIN PitchersWithCasey p
ON
p.masterID=m.masterID
INNER JOIN baseball.dbo.teams t
ON
t.teamID=p.teamID and t.yearID=p.yearID
ORDER BY p.yearID,t.name

/*Query 14

Two degrees from Yogi Berra - List the name of each player who appeared on a team with a player that was at one time was a teamate of Yogi Berra. 
So suppose player A was a teamate of Yogi Berra. Then player A is one-degree of separation from Yogi Berra. Let player B be related to player A because A played on a team in the same year with player A. 
Then player A is two-degrees of separation from player A.

*/

WITH PlayersWhoPlayedWithYogi
AS(
		SELECT DISTINCT a2.masterID "PlayerOneDegree"
		FROM
		baseball.dbo.appearances a1
		INNER JOIN
		baseball.dbo.appearances a2
		ON
		a1.teamID=a2.teamID AND a1.yearID=a2.yearID AND a1.masterID!=a2.masterID
		WHERE a1.masterID= (
							 SELECT DISTINCT masterID
							 FROM
							 baseball.dbo.master
							 WHERE nameFirst='Yogi' AND nameLast='Berra'
							)
)
--SELECT * FROM PlayersWhoPlayedWithYogi
,
SecondDegreePlayer AS
(
		SELECT p2.masterID,p1.teamID,p1.yearID
		FROM
		baseball.dbo.appearances p1
		INNER JOIN
		baseball.dbo.appearances p2
		ON
		p1.yearID=p2.yearID AND p1.teamID=p2.teamID AND p1.masterID != p2.masterID
		WHERE p1.masterID in (SELECT PlayerOneDegree FROM PlayersWhoPlayedWithYogi)
		AND
		p2.masterID!= (
							 SELECT DISTINCT masterID
							 FROM
							 baseball.dbo.master
							 WHERE nameFirst='Yogi' AND nameLast='Berra'
					) 							
)

SELECT DISTINCT m.nameFirst "First Name",m.nameLast "Last Name" FROM SecondDegreePlayer s
INNER JOIN baseball.dbo.master m
ON
m.masterID=s.masterID
ORDER BY m.nameLast

/* QUERY 15 

Median team wins - For the 1970s, list the team name for teams in the National League ("NL") 
that had the median number of total wins in the decade (1970-1979 inclusive).

*/


WITH NationalLeagueTeamsInSeventees
AS(
		SELECT TOP 100 PERCENT t.teamID,sum(t.W) TotalWins
		FROM 
		baseball.dbo.teams t
		WHERE t.yearID>=1970 AND t.yearID<=1979 AND t.lgID='NL'
		GROUP BY t.teamID
		ORDER BY sum(t.W) DESC
),
GetTeamAccordingToRank
AS(
		SELECT ROW_NUMBER() OVER( ORDER BY TotalWins DESC) RANK,teamID
		FROM NationalLeagueTeamsInSeventees
),
GetMedianIndex
AS(
		SELECT count(teamID)/2+1 Median 
		/* in the results given in with this query, it is assumed that the median is at number of teams/2
		so if it where 12 teams, it would come out to be at 6, but thats not the median when we have
		even number of elements. It should be average of teams/2 and teams/2 + 1, but since that isnt assumed
		and to get the result matching with the expected result, median i have taken is number of teams/2 + 1
		*/
		FROM 
		NationalLeagueTeamsInSeventees
),
GetTeamAtMedian
AS(
		SELECT DISTINCT t.name,g.RANK
		FROM
		GetTeamAccordingToRank g
		INNER JOIN baseball.dbo.teams t
		ON
		g.teamID=t.teamID
		WHERE
		g.RANK = ( SELECT * FROM GetMedianIndex) AND t.yearID>=1970 AND t.yearID<=1979
)
SELECT * FROM GetTeamAtMedian


