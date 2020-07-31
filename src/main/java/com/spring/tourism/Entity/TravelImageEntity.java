package com.spring.tourism.Entity;

import javax.persistence.*;
import java.util.Objects;

@Entity
@Table(name = "travel_image", schema = "public", catalog = "travel")
@IdClass(TravelImageEntityPK.class)
public class TravelImageEntity {
    private String travelId;
    private String imageAddress;

    @Id
    @Column(name = "travel_id")
    public String getTravelId() {
        return travelId;
    }

    public void setTravelId(String travelId) {
        this.travelId = travelId;
    }

    @Id
    @Column(name = "image_address")
    public String getImageAddress() {
        return imageAddress;
    }

    public void setImageAddress(String imageAddress) {
        this.imageAddress = imageAddress;
    }

    @Override
    public boolean equals(Object o) {
        if (this == o) return true;
        if (o == null || getClass() != o.getClass()) return false;

        TravelImageEntity that = (TravelImageEntity) o;

        if (!Objects.equals(travelId, that.travelId)) return false;
        if (!Objects.equals(imageAddress, that.imageAddress)) return false;

        return true;
    }

    @Override
    public int hashCode() {
        int result = travelId != null ? travelId.hashCode() : 0;
        result = 31 * result + (imageAddress != null ? imageAddress.hashCode() : 0);
        return result;
    }
}
