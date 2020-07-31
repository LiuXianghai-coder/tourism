package com.spring.tourism.Repository;

import com.spring.tourism.Entity.RaiderEntity;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.CrudRepository;
import org.springframework.data.repository.query.Param;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;

public interface RaiderEntityRepository extends CrudRepository<RaiderEntity, String> {
    RaiderEntity getRaiderEntityByRaiderId(String raiderId);

    @Modifying
    @Transactional
    @Query(value = "SELECT id AS raider_id, title AS raider_title, stars AS stars, " +
            "visits AS visits, raiderCal AS raider_date, date_diff AS date_between " +
            "FROM update_date_between() LIMIT :size OFFSET :start", nativeQuery = true)
    List<RaiderEntity> getRaiderEntityByStartAndEnd(@Param("size") Integer size,
                                                    @Param("start") Integer start);

    @Modifying
    @Transactional
    @Query(value = "SELECT id AS raider_id, title AS raider_title, stars AS stars," +
            "visits AS visits, raider_cal AS raider_date, date_diff AS date_between " +
            "FROM find_search_raider(:keyWord)", nativeQuery = true)
    List<RaiderEntity> getRaiderEntityByKeyWord(@Param("keyWord") String keyWord);

    @Modifying
    @Transactional
    @Query(value = "SELECT id AS raider_id, title AS raider_title, stars AS stars, " +
            "visits, raiderCal AS raider_date, date_diff AS date_between " +
            "FROM update_date_between() ORDER BY stars DESC", nativeQuery = true)
    List<RaiderEntity> getRaiderEntitiesOrderByStar();

    @Modifying
    @Transactional
    @Query(value = "SELECT id AS raider_id, title AS raider_title, stars AS stars, " +
            "visits AS visits, raiderCal AS raider_date, date_diff AS date_between " +
            "FROM update_date_between() ORDER BY visits DESC ", nativeQuery = true)
    List<RaiderEntity> getRaiderEntitiesOrderByVisitNum();

    @Modifying
    @Transactional
    @Query(value = "UPDATE raider SET visits = visits + 1 WHERE raider_id = :raiderId",
            nativeQuery = true)
    void updateVisitNum(@Param("raiderId") String raiderId);

    @Query(value = "SELECT id AS raider_id, title AS raider_title, stars AS stars,\n" +
            "       visits AS visits, raiderCal AS raider_date, date_diff AS date_between " +
            "FROM update_date_between()\n " +
            "WHERE id IN (SELECT raider_id FROM user_raider WHERE user_id = :userId)", nativeQuery = true)
    List<RaiderEntity> getRaiderEntitiesByUserId(@Param("userId") String userId);

    @Query(value = "SELECT * FROM raider WHERE raider_id IN (SELECT " +
            "raider_id FROM user_save_raider WHERE user_id = :userId)", nativeQuery = true)
    List<RaiderEntity> getSaveRaiderEntitiesByUserId(@Param("userId") String userId);


    @Query(value = "SELECT * FROM raider WHERE raider_id IN (SELECT " +
            "raider_id FROM user_star_raider WHERE user_id = :userId)", nativeQuery = true)
    List<RaiderEntity> getStarRaiderEntityByUserId(@Param("userId") String userId);

    @Query(value = "SELECT * FROM raider WHERE raider_id IN " +
            "(SELECT raider_id FROM raider_comment WHERE user_id=:userId)", nativeQuery = true)
    List<RaiderEntity> getCommentRaiderEntitiesByUserId(@Param("userId") String userId);
}
