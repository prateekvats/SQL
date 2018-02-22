
/* Constraint 1
The default number of ABs is 20.
*/

ALTER TABLE dbo.batting 
ADD CONSTRAINT DefaultABValue DEFAULT 20 for AB;


/* Constraint 2
A player cannot have more H (hits) than AB (at bats).
*/

ALTER TABLE dbo.batting
ADD CONSTRAINT AB_Always_Greater CHECK (H<=AB);

/* Constraint 3
In the Teams table, the league can be only one of the values: NL or AL.
*/

ALTER TABLE dbo.teams
ADD CONSTRAINT LeagueValueContraint CHECK (lgID IN ('NL','AL'));


/* Constraint 4
When a team loses more than 161 games in a season, the fans want to forget about the team forever, so all batting records for the team for that year should be deleted.
*/
DROP TRIGGER destroyLoserTeam

CREATE TRIGGER destroyLoserTeam
    ON dbo.teams
    AFTER INSERT
AS 
	IF EXISTS(SELECT SUM(T.L) FROM TEAMS T INNER JOIN INSERTED I  ON 
					   T.TEAMID = I.TEAMID GROUP BY T.teamID, T.yearID HAVING  SUM(T.L)>161 )
	DELETE FROM BATTING WHERE teamID=(SELECT teamID FROM INSERTED) AND yearID=(SELECT yearID FROM INSERTED) 


/* Constraint 5
If a player wins the MVP, WS MVP, and a Gold Glove in the same season, they are automatically inducted into the Hall of Fame.

masterID - using inserted
yearid - using inserted
votedBy- prateek
ballots- null
needed - null
votes - null
inducted - Y
category - Player
needed_note_ null

*/
CREATE TRIGGER inductToHallOfFame
    ON dbo.awardsplayers
    AFTER INSERT,UPDATE
AS 
	IF EXISTS(
	
		SELECT count(awp.awardId) awards,awp.yearID,awp.masterID
		FROM dbo.awardsplayers awp 
		INNER JOIN INSERTED i
		ON 
		awp.masterID=i.masterID AND awp.yearID=i.yearID
		WHERE awp.awardID in ('World Series MVP','Most Valuable Player','Gold Glove')
		GROUP by awp.yearID,awp.masterID
		HAVING count(awp.awardId)>2
	
	 )
	INSERT INTO [dbo].[halloffame]([masterID],[yearid],[votedBy],[inducted])
	    SELECT inserted.masterId,inserted.yearID,'Prateek','Y' FROM inserted



/* Constraint 6
All teams must have some name, i.e., it cannot be null.

To check if the constraint was running i had to delete all the null values
using this  query
DELETE FROM teams where teamID in (SELECT teamID FROM teams where name is null);
then tested my constraint by inserting a null team name
INSERT INTO teams(yearID,lgID,teamID) Values(1899,'al','pvt')
*/


ALTER TABLE dbo.teams
ADD CONSTRAINT TeamNameContraint CHECK (name is not NULL);


/* Constraint 7
Everybody has a unique name (combined first and last names).
The below constraint will not let me insert a row with two names, Jon Smith and Jon Snow, because the constraint is applied on 
first name and last name separately. That is why i created a trigger as well, to allow insertion of only unique names(combination of first name and last name)


*/


ALTER TABLE dbo.master
DROP CONSTRAINT UniqueNames UNIQUE(nameFirst,nameLast);

/* DO NOT ALLOW non-unique names */
CREATE TRIGGER uniqueNameCheck
    ON dbo.master
    FOR INSERT,UPDATE
AS 
BEGIN
    if exists(
        select *
        from inserted
        where exists (
            select count(masterID)
            from master
            where nameFirst = inserted.nameFirst
                and nameLast = inserted.nameLast
			group by nameFirst,nameLast
			HAVING count(masterID)>1
        ))
    begin
        raiserror('Duplicate name', 10, 1)
		Rollback;
    end
END;
