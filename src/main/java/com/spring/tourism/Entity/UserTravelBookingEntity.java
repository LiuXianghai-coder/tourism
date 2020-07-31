package com.spring.tourism.Entity;

import javax.persistence.*;
import java.util.Objects;

@Entity
@Table(name = "user_travel_booking", schema = "public", catalog = "travel")
@IdClass(UserTravelBookingEntityPK.class)
public class UserTravelBookingEntity {
    private String userId;
    private String travelId;
    private double travelPrice;
    private String bookDate;

    @Id
    @Column(name = "user_id")
    public String getUserId() {
        return userId;
    }

    public void setUserId(String userId) {
        this.userId = userId;
    }

    @Id
    @Column(name = "travel_id")
    public String getTravelId() {
        return travelId;
    }

    public void setTravelId(String travelId) {
        this.travelId = travelId;
    }

    @Basic
    @Column(name = "travel_price")
    public double getTravelPrice() {
        return travelPrice;
    }

    public void setTravelPrice(double travelPrice) {
        this.travelPrice = travelPrice;
    }

    @Basic
    @Column(name = "book_date")
    public String getBookDate() {
        return bookDate;
    }

    public void setBookDate(String bookDate) {
        this.bookDate = bookDate;
    }

    @Override
    public boolean equals(Object o) {
        if (this == o) return true;
        if (o == null || getClass() != o.getClass()) return false;

        UserTravelBookingEntity that = (UserTravelBookingEntity) o;

        if (Double.compare(that.travelPrice, travelPrice) != 0) return false;
        if (!Objects.equals(userId, that.userId)) return false;
        if (!Objects.equals(travelId, that.travelId)) return false;
        if (!Objects.equals(bookDate, that.bookDate)) return false;

        return true;
    }

    @Override
    public int hashCode() {
        int result;
        long temp;
        result = userId != null ? userId.hashCode() : 0;
        result = 31 * result + (travelId != null ? travelId.hashCode() : 0);
        temp = Double.doubleToLongBits(travelPrice);
        result = 31 * result + (int) (temp ^ (temp >>> 32));
        result = 31 * result + (bookDate != null ? bookDate.hashCode() : 0);
        return result;
    }
}
