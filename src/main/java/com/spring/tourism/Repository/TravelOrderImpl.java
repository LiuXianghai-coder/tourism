package com.spring.tourism.Repository;

import com.spring.tourism.DAO.TravelOrderDAO;
import com.spring.tourism.Entity.TravelOrder;
import com.spring.tourism.RowMapper.TravelOrderMapper;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.lang.NonNull;

import java.util.ArrayList;
import java.util.List;

public class TravelOrderImpl implements TravelOrderDAO {
    private JdbcTemplate jdbcTemplate;

    public TravelOrderImpl(JdbcTemplate jdbcTemplate) {
        this.jdbcTemplate = jdbcTemplate;
    }

    @Override
    public List<TravelOrder> getAllTravelOrders(@NonNull String userId) {
        try {
            String sql = "SELECT travel_id, travel_title, travel_score, num_people, travel_price,\n" +
                    "       book_date, user_id, image_address, travel_date\n" +
                    "FROM (SELECT travel_image.travel_id, travel_title, travel_score,\n" +
                    "                      num_people, travel_price, book_date, user_id,\n" +
                    "                      image_address, travel_date,  row_number() over (PARTITION BY\n" +
                    "           travel_temp.travel_id ORDER BY image_address DESC )\n" +
                    "    AS rn FROM (SELECT travel_product.*, NULL AS book_date, ? AS user_id\n" +
                    "FROM  travel_product JOIN (SELECT * FROM travel_product\n" +
                    " WHERE travel_id IN (SELECT travel_id FROM user_travel_booking WHERE user_id=?)\n" +
                    "    OR travel_id IN (SELECT travel_id FROM user_travel_save WHERE user_id=?)) AS travel_id_temp\n" +
                    "ON travel_product.travel_id=travel_id_temp.travel_id) AS travel_temp JOIN travel_image\n" +
                    "    ON travel_temp.travel_id=travel_image.travel_id) AS result WHERE rn=1";

            return jdbcTemplate.query(sql, new Object[]{userId, userId, userId}, new TravelOrderMapper());
        } catch (Exception e) {
            System.out.println("获取指定的旅游项目序列失败！");
            return new ArrayList<>();
        }
    }

    @Override
    public List<TravelOrder> getWillTravelOrders(@NonNull String userId) {
        try {
            String sql = "SELECT user_id,book_date,travel_id,travel_title,travel_score,\n" +
                    "       num_people, travel_price, travel_date, image_address\n" +
                    "FROM (SELECT user_travel_booking.user_id, user_travel_booking.book_date,\n" +
                    "             travel_product.*, image_address,\n" +
                    "             row_number() over (PARTITION BY travel_product.travel_id\n" +
                    "                 ORDER BY image_address DESC ) AS rn\n" +
                    "      FROM user_travel_booking\n" +
                    "               JOIN travel_product\n" +
                    "                    ON user_travel_booking.travel_id = travel_product.travel_id AND user_id = ?\n" +
                    "               JOIN travel_image ON travel_image.travel_id = travel_product.travel_id) AS temp\n" +
                    "WHERE rn = 1 \n" +
                    "AND current_date < travel_date";
            return jdbcTemplate.query(sql, new Object[]{userId}, new TravelOrderMapper());
        } catch (Exception e) {
            System.out.println("获取指定的旅游项目序列失败！");
            return new ArrayList<>();
        }
    }

    @Override
    public List<TravelOrder> getHasTravelOrders(@NonNull String userId) {
        try {
            String sql = "SELECT user_id,book_date,travel_id,travel_title,travel_score,\n" +
                    "       num_people, travel_price, travel_date, image_address\n" +
                    "FROM (SELECT user_travel_booking.user_id, user_travel_booking.book_date,\n" +
                    "             travel_product.*, image_address,\n" +
                    "             row_number() over (PARTITION BY travel_product.travel_id\n" +
                    "                 ORDER BY image_address DESC ) AS rn\n" +
                    "      FROM user_travel_booking\n" +
                    "               JOIN travel_product\n" +
                    "                    ON user_travel_booking.travel_id = travel_product.travel_id AND user_id = ?\n" +
                    "               JOIN travel_image ON travel_image.travel_id = travel_product.travel_id) AS temp\n" +
                    "WHERE rn = 1 \n" +
                    "AND current_date > travel_date";

            return jdbcTemplate.query(sql, new Object[]{userId}, new TravelOrderMapper());
        } catch (Exception e) {
            System.out.println("获取指定的旅游项目序列失败！");
            return new ArrayList<>();
        }
    }

    @Override
    public List<TravelOrder> getAllSaveTravelOrders(@NonNull String userId) {
        try {
            String sql = "SELECT user_id,\n" +
                    "       book_date,\n" +
                    "       travel_id,\n" +
                    "       travel_title,\n" +
                    "       travel_score,\n" +
                    "       num_people,\n" +
                    "       travel_price,\n" +
                    "       travel_date,\n" +
                    "       image_address\n" +
                    "FROM (SELECT user_travel_save.user_id,\n" +
                    "             NULL       AS book_date,\n" +
                    "             travel_product.*,\n" +
                    "             image_address,\n" +
                    "             row_number() over (PARTITION BY travel_product.travel_id ORDER BY image_address DESC ) AS rn\n" +
                    "      FROM user_travel_save\n" +
                    "               JOIN travel_product\n" +
                    "                    ON user_travel_save.travel_id = travel_product.travel_id AND user_id = ?\n" +
                    "               JOIN travel_image ON travel_image.travel_id = travel_product.travel_id) AS temp\n" +
                    "WHERE rn = 1;";

            return jdbcTemplate.query(sql, new Object[]{userId}, new TravelOrderMapper());
        } catch (Exception e) {
            System.out.println("获取指定的旅游项目序列失败！");
            return new ArrayList<>();
        }
    }
}
