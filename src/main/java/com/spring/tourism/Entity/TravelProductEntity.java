package com.spring.tourism.Entity;

import javax.persistence.*;
import java.sql.Date;
import java.util.Objects;

@Entity
@Table(name = "travel_product", schema = "public", catalog = "travel")
public class TravelProductEntity {
    private String travelId;
    private String travelTitle;
    private Double travelScore;
    private Integer numPeople;
    private Double travelPrice;
    private Date   travelDate;

    @Id
    @Column(name = "travel_id")
    public String getTravelId() {
        return travelId;
    }

    public void setTravelId(String travelId) {
        this.travelId = travelId;
    }

    @Basic
    @Column(name = "travel_title")
    public String getTravelTitle() {
        return travelTitle;
    }

    public void setTravelTitle(String travelTitle) {
        this.travelTitle = travelTitle;
    }

    @Basic
    @Column(name = "travel_score")
    public Double getTravelScore() {
        return travelScore;
    }

    public void setTravelScore(Double travelScore) {
        this.travelScore = travelScore;
    }

    @Basic
    @Column(name = "num_people")
    public Integer getNumPeople() {
        return numPeople;
    }

    public void setNumPeople(Integer numPeople) {
        this.numPeople = numPeople;
    }

    @Basic
    @Column(name = "travel_price")
    public Double getTravelPrice() {
        return travelPrice;
    }

    public void setTravelPrice(Double travelPrice) {
        this.travelPrice = travelPrice;
    }

    @Basic
    @Column(name = "travel_date")
    public Date getTravelDate() {
        return travelDate;
    }

    public void setTravelDate(Date travelDate) {
        this.travelDate = travelDate;
    }

    @Override
    public boolean equals(Object o) {
        if (this == o) return true;
        if (o == null || getClass() != o.getClass()) return false;

        TravelProductEntity that = (TravelProductEntity) o;

        if (!Objects.equals(travelId, that.travelId)) return false;
        if (!Objects.equals(travelTitle, that.travelTitle)) return false;
        if (!Objects.equals(travelScore, that.travelScore)) return false;
        if (!Objects.equals(numPeople, that.numPeople)) return false;
        return Objects.equals(travelPrice, that.travelPrice);
    }

    @Override
    public int hashCode() {
        int result = travelId != null ? travelId.hashCode() : 0;
        result = 31 * result + (travelTitle != null ? travelTitle.hashCode() : 0);
        result = 31 * result + (travelScore != null ? travelScore.hashCode() : 0);
        result = 31 * result + (numPeople != null ? numPeople.hashCode() : 0);
        result = 31 * result + (travelPrice != null ? travelPrice.hashCode() : 0);
        return result;
    }
}
